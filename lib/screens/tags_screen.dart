import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unicons/unicons.dart';
import '../theme/app_theme.dart';
import '../services/providers.dart';
import '../models/tag.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddTagScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 64,
                    color: AppTheme.rhythmLightGray,
                  ),
                  const SizedBox(height: AppTheme.spacePulse3),
                  Text(
                    'No tags yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.rhythmMediumGray,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spacePulse2),
                  Text(
                    'Tap + to create your first tag',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.rhythmLightGray,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.spacePulse3),
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppTheme.spacePulse2),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppTheme.rhythmBlack,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _getUniconFromName(tag.emoji),
                        size: 24,
                        color: AppTheme.rhythmWhite,
                      ),
                    ),
                  ),
                  title: Text(tag.name),
                  subtitle: Text(
                    tag.category,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.rhythmMediumGray,
                        ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, tag),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Error loading tags: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Tag tag) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Tag'),
          content: Text('Are you sure you want to delete "${tag.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (tag.id != null) {
                  final db = ref.read(databaseProvider);
                  await db.deleteTag(tag.id!);
                  ref.invalidate(allTagsProvider);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tag deleted')),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  IconData _getUniconFromName(String iconName) {
    final iconMap = <String, IconData>{
      'star': UniconsLine.star,
      'heart': UniconsLine.heart,
      'smile': UniconsLine.smile,
      'book': UniconsLine.book,
      'briefcase': UniconsLine.briefcase,
      'home': UniconsLine.home,
      'dumbbell': UniconsLine.dumbbell,
      'moon': UniconsLine.moon,
      'sun': UniconsLine.sun,
      'calendar': UniconsLine.calendar_alt,
      'clock': UniconsLine.clock,
      'bell': UniconsLine.bell,
      'shield': UniconsLine.shield,
      'lock': UniconsLine.lock,
      'key': UniconsLine.lock_alt,
      'user': UniconsLine.user,
      'users': UniconsLine.users_alt,
      'coffee': UniconsLine.coffee,
      'glass_martini': UniconsLine.glass_martini,
      'music': UniconsLine.music,
      'camera': UniconsLine.camera,
      'image': UniconsLine.image,
      'video': UniconsLine.video,
      'play_circle': UniconsLine.play_circle,
      'pause_circle': UniconsLine.pause_circle,
      'game_structure': UniconsLine.game_structure,
      'brush_alt': UniconsLine.brush_alt,
      'pen': UniconsLine.pen,
      'edit_alt': UniconsLine.edit_alt,
      'file_alt': UniconsLine.file_alt,
      'folder': UniconsLine.folder,
      'graduation_cap': UniconsLine.graduation_cap,
      'hospital': UniconsLine.hospital,
      'bed': UniconsLine.bed,
      'exclamation_triangle': UniconsLine.exclamation_triangle,
      'check_circle': UniconsLine.check_circle,
      'times_circle': UniconsLine.times_circle,
      'plus_circle': UniconsLine.plus_circle,
      'minus_circle': UniconsLine.minus_circle,
      'arrow_up': UniconsLine.arrow_up,
      'arrow_down': UniconsLine.arrow_down,
      'arrow_left': UniconsLine.arrow_left,
      'arrow_right': UniconsLine.arrow_right,
      'fire': UniconsLine.fire,
      'bolt': UniconsLine.bolt,
      'cloud': UniconsLine.cloud,
      'temperature': UniconsLine.temperature,
      'tear': UniconsLine.tear,
      // Default tags
      'sick': UniconsLine.frown,
      'annoyed': UniconsLine.meh,
      'virus_slash': UniconsLine.shield,
      'ban': UniconsLine.ban,
      'user_arrows': UniconsLine.arrow_circle_up,
      'head_side': UniconsLine.head_side,
      'head_side_cough': UniconsLine.head_side_cough,
      'sad': UniconsLine.sad,
      'clinic_medical': UniconsLine.clinic_medical,
    };

    return iconMap[iconName] ?? UniconsLine.question_circle;
  }
}

class AddTagScreen extends ConsumerStatefulWidget {
  const AddTagScreen({super.key});

  @override
  ConsumerState<AddTagScreen> createState() => _AddTagScreenState();
}

class _AddTagScreenState extends ConsumerState<AddTagScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedEmoji = 'star';
  String _selectedCategory = 'General';

  // Available Unicons icon names
  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'star', 'icon': UniconsLine.star},
    {'name': 'heart', 'icon': UniconsLine.heart},
    {'name': 'smile', 'icon': UniconsLine.smile},
    {'name': 'book', 'icon': UniconsLine.book},
    {'name': 'briefcase', 'icon': UniconsLine.briefcase},
    {'name': 'home', 'icon': UniconsLine.home},
    {'name': 'dumbbell', 'icon': UniconsLine.dumbbell},
    {'name': 'moon', 'icon': UniconsLine.moon},
    {'name': 'sun', 'icon': UniconsLine.sun},
    {'name': 'calendar', 'icon': UniconsLine.calendar_alt},
    {'name': 'clock', 'icon': UniconsLine.clock},
    {'name': 'bell', 'icon': UniconsLine.bell},
    {'name': 'shield', 'icon': UniconsLine.shield},
    {'name': 'lock', 'icon': UniconsLine.lock},
    {'name': 'key', 'icon': UniconsLine.lock_alt},
    {'name': 'user', 'icon': UniconsLine.user},
    {'name': 'users', 'icon': UniconsLine.users_alt},
    {'name': 'coffee', 'icon': UniconsLine.coffee},
    {'name': 'glass_martini', 'icon': UniconsLine.glass_martini},
    {'name': 'music', 'icon': UniconsLine.music},
    {'name': 'camera', 'icon': UniconsLine.camera},
    {'name': 'image', 'icon': UniconsLine.image},
    {'name': 'video', 'icon': UniconsLine.video},
    {'name': 'play_circle', 'icon': UniconsLine.play_circle},
    {'name': 'pause_circle', 'icon': UniconsLine.pause_circle},
    {'name': 'game_structure', 'icon': UniconsLine.game_structure},
    {'name': 'brush_alt', 'icon': UniconsLine.brush_alt},
    {'name': 'pen', 'icon': UniconsLine.pen},
    {'name': 'edit_alt', 'icon': UniconsLine.edit_alt},
    {'name': 'file_alt', 'icon': UniconsLine.file_alt},
    {'name': 'folder', 'icon': UniconsLine.folder},
    {'name': 'graduation_cap', 'icon': UniconsLine.graduation_cap},
    {'name': 'hospital', 'icon': UniconsLine.hospital},
    {'name': 'bed', 'icon': UniconsLine.bed},
    {'name': 'exclamation_triangle', 'icon': UniconsLine.exclamation_triangle},
    {'name': 'check_circle', 'icon': UniconsLine.check_circle},
    {'name': 'times_circle', 'icon': UniconsLine.times_circle},
    {'name': 'plus_circle', 'icon': UniconsLine.plus_circle},
    {'name': 'minus_circle', 'icon': UniconsLine.minus_circle},
    {'name': 'arrow_up', 'icon': UniconsLine.arrow_up},
    {'name': 'arrow_down', 'icon': UniconsLine.arrow_down},
    {'name': 'arrow_left', 'icon': UniconsLine.arrow_left},
    {'name': 'arrow_right', 'icon': UniconsLine.arrow_right},
    {'name': 'fire', 'icon': UniconsLine.fire},
    {'name': 'bolt', 'icon': UniconsLine.bolt},
    {'name': 'cloud', 'icon': UniconsLine.cloud},
    {'name': 'temperature', 'icon': UniconsLine.temperature},
    {'name': 'tear', 'icon': UniconsLine.tear},
  ];

  final List<String> _categories = [
    'General',
    'Health',
    'Work',
    'Personal',
    'Hobby',
    'Social',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Tag'),
        actions: [
          TextButton(
            onPressed: _saveTag,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        children: [
          // Tag name
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tag Name',
                  hintText: 'Enter tag name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacePulse3),

          // Emoji selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Symbol',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacePulse3),
                  // Preview
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppTheme.rhythmBlack,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          _availableIcons.firstWhere((i) => i['name'] == _selectedEmoji)['icon'],
                          size: 40,
                          color: AppTheme.rhythmWhite,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacePulse3),
                  // Icon grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _availableIcons.length,
                    itemBuilder: (context, index) {
                      final iconData = _availableIcons[index];
                      final iconName = iconData['name'] as String;
                      final icon = iconData['icon'] as IconData;
                      final isSelected = iconName == _selectedEmoji;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedEmoji = iconName;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.rhythmBlack
                                : AppTheme.rhythmLightGray.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              icon,
                              size: 20,
                              color: isSelected
                                  ? AppTheme.rhythmWhite
                                  : AppTheme.rhythmBlack,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacePulse3),

          // Category selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacePulse2),
                  Wrap(
                    spacing: AppTheme.spacePulse2,
                    runSpacing: AppTheme.spacePulse2,
                    children: _categories.map((category) {
                      final isSelected = category == _selectedCategory;
                      return ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          }
                        },
                        selectedColor: AppTheme.rhythmBlack,
                        labelStyle: TextStyle(
                          color: isSelected
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
        ],
      ),
    );
  }

  Future<void> _saveTag() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a tag name')),
      );
      return;
    }

    final tag = Tag(
      name: name,
      emoji: _selectedEmoji,
      category: _selectedCategory,
    );

    try {
      final db = ref.read(databaseProvider);
      await db.createTag(tag);
      ref.invalidate(allTagsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tag created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}
