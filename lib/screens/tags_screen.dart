import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unicons/unicons.dart';
import '../theme/app_theme.dart';
import '../services/providers.dart';
import '../models/tag.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(allTagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        automaticallyImplyLeading: false,
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
      body: _buildGroupedTags(context, ref),
    );
  }

  Widget _buildGroupedTags(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);
    final categoriesAsync = ref.watch(allTagCategoriesProvider);

    return tagsAsync.when(
      data: (tags) {
        return categoriesAsync.when(
          data: (categories) {
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

            // Group tags by category
            final grouped = <String, List<Tag>>{};
            for (final tag in tags) {
              grouped.putIfAbsent(tag.category, () => []).add(tag);
            }

            // Ensure categories list covers all keys
            final orderedCategories = [
              ...categories.map((c) => c.name),
              ...grouped.keys.where((k) => !categories.any((c) => c.name == k)),
            ];

            return ListView(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              children: [
                // Categories management section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacePulse3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Categories',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              tooltip: 'Add Category',
                              onPressed: () => _showAddCategoryDialog(context, ref),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacePulse2),
                        Wrap(
                          spacing: AppTheme.spacePulse2,
                          runSpacing: AppTheme.spacePulse2,
                          children: orderedCategories.map<Widget>((name) {
                            return ActionChip(
                              label: Text(name),
                              onPressed: () => _showEditCategoryDialog(context, ref, name),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacePulse3),

                // Instruction text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacePulse2),
                  child: Text(
                    'Drag to move • Long press to edit',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.rhythmMediumGray,
                          fontStyle: FontStyle.italic,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppTheme.spacePulse3),

                // Tags grouped by category - journal style
                ...orderedCategories.map((categoryName) {
                  final categoryTags = grouped[categoryName] ?? [];

                  return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacePulse3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    categoryName,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.rhythmMediumGray,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Tag'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddTagScreen(initialCategory: categoryName),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppTheme.spacePulse2,
                                        vertical: 0,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacePulse3),

                              if (categoryTags.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppTheme.spacePulse3),
                                    child: Text(
                                      'No tags in this category',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppTheme.rhythmLightGray,
                                          ),
                                    ),
                                  ),
                                )
                              else
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    const int columns = 5;
                                    final double spacing = AppTheme.spacePulse3.toDouble();
                                    final double totalSpacing = spacing * (columns - 1);
                                    final double itemWidth = (constraints.maxWidth - totalSpacing) / columns;

                                    // Split tags into rows of 5
                                    final rows = <List<Tag>>[];
                                    for (var i = 0; i < categoryTags.length; i += columns) {
                                      rows.add(categoryTags.sublist(
                                        i,
                                        i + columns > categoryTags.length ? categoryTags.length : i + columns,
                                      ));
                                    }

                                    return Column(
                                      children: rows.map((rowTags) {
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: rows.last == rowTags ? 0 : spacing,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: rowTags.asMap().entries.map<Widget>((entry) {
                                              final index = entry.key;
                                              final tag = entry.value;
                                              final originalIndex = categoryTags.indexOf(tag);

                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  right: index < rowTags.length - 1 ? spacing : 0,
                                                ),
                                                child: DragTarget<Tag>(
                                                  onWillAccept: (draggedTag) {
                                                    return draggedTag != null && draggedTag.id != tag.id;
                                                  },
                                                  onAccept: (draggedTag) async {
                                                    final db = ref.read(databaseProvider);

                                                    if (draggedTag.category == categoryName) {
                                                      // Reorder within same category
                                                      final oldIndex = categoryTags.indexWhere((t) => t.id == draggedTag.id);
                                                      if (oldIndex != -1 && oldIndex != originalIndex) {
                                                        final newList = List<Tag>.from(categoryTags);
                                                        newList.removeAt(oldIndex);
                                                        newList.insert(originalIndex, draggedTag);

                                                        await db.updateTagOrders(
                                                          categoryName,
                                                          newList.map<int>((t) => t.id as int).toList(),
                                                        );
                                                        ref.invalidate(allTagsProvider);

                                                        if (mounted) {
                                                          HapticFeedback.lightImpact();
                                                        }
                                                      }
                                                    } else {
                                                      // Move to different category at specific position
                                                      await db.updateTag(draggedTag.copyWith(category: categoryName));

                                                      // Insert at the target position
                                                      final newList = List<Tag>.from(categoryTags);
                                                      newList.insert(originalIndex, draggedTag.copyWith(category: categoryName));

                                                      await db.updateTagOrders(
                                                        categoryName,
                                                        newList.map<int>((t) => t.id as int).toList(),
                                                      );
                                                      ref.invalidate(allTagsProvider);

                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('${draggedTag.name} moved to $categoryName')),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  builder: (context, candidateData, rejectedData) {
                                                    final isTargeted = candidateData.isNotEmpty;

                                                    return SizedBox(
                                                      width: itemWidth,
                                                      child: Draggable<Tag>(
                                                        data: tag,
                                                        maxSimultaneousDrags: 1,
                                                        feedback: Material(
                                                          color: Colors.transparent,
                                                          child: Opacity(
                                                            opacity: 0.85,
                                                            child: Container(
                                                              width: itemWidth,
                                                              child: _buildTagItem(context, tag, true, itemWidth),
                                                            ),
                                                          ),
                                                        ),
                                                        childWhenDragging: Opacity(
                                                          opacity: 0.3,
                                                          child: _buildTagItem(context, tag, false, itemWidth),
                                                        ),
                                                        onDragStarted: () {
                                                          HapticFeedback.mediumImpact();
                                                        },
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            border: isTargeted
                                                                ? Border.all(
                                                                    color: AppTheme.rhythmBlack,
                                                                    width: 2,
                                                                  )
                                                                : null,
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: GestureDetector(
                                                            onLongPress: () {
                                                              HapticFeedback.heavyImpact();
                                                              _showEditTagDialog(context, ref, tag);
                                                            },
                                                            child: _buildTagItem(context, tag, false, itemWidth),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                }),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error loading categories: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error loading tags: $error')),
    );
  }

  Widget _buildTagItem(BuildContext context, Tag tag, bool isSelected, double width) {
    return Align(
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.rhythmBlack
                  : AppTheme.rhythmLightGray.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                _getUniconFromName(tag.emoji),
                size: 20,
                color: isSelected
                    ? AppTheme.rhythmWhite
                    : AppTheme.rhythmBlack,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse1),
          SizedBox(
            width: 52,
            height: 24,
            child: Text(
              tag.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 8,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Category name'),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                final db = ref.read(databaseProvider);
                await db.createTagCategory(TagCategory(name: name));
                ref.invalidate(allTagCategoriesProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditCategoryDialog(BuildContext context, WidgetRef ref, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final categories = await ref.read(allTagCategoriesProvider.future);
    final category = categories.firstWhere((c) => c.name == currentName, orElse: () => TagCategory(name: currentName));
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Category name'),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (category.id != null) {
                  final db = ref.read(databaseProvider);
                  await db.deleteTagCategory(category.id!);
                  ref.invalidate(allTagCategoriesProvider);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                final db = ref.read(databaseProvider);
                if (category.id != null) {
                  await db.updateTagCategory(category.copyWith(name: name));
                } else {
                  await db.createTagCategory(TagCategory(name: name));
                }
                ref.invalidate(allTagCategoriesProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditTagDialog(BuildContext context, WidgetRef ref, Tag tag) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTagScreen(tag: tag),
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
  final String? initialCategory;
  const AddTagScreen({super.key, this.initialCategory});

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
    if (widget.initialCategory != null && _selectedCategory == 'General') {
      _selectedCategory = widget.initialCategory!;
    }
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

class EditTagScreen extends ConsumerStatefulWidget {
  final Tag tag;
  const EditTagScreen({super.key, required this.tag});

  @override
  ConsumerState<EditTagScreen> createState() => _EditTagScreenState();
}

class _EditTagScreenState extends ConsumerState<EditTagScreen> {
  late TextEditingController _nameController;
  late String _selectedEmoji;
  late String _selectedCategory;

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
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag.name);
    _selectedEmoji = widget.tag.emoji;
    _selectedCategory = widget.tag.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Tag'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
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
                          _availableIcons.firstWhere((i) => i['name'] == _selectedEmoji, orElse: () => _availableIcons[0])['icon'],
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

    final updatedTag = widget.tag.copyWith(
      name: name,
      emoji: _selectedEmoji,
      category: _selectedCategory,
    );

    try {
      final db = ref.read(databaseProvider);
      await db.updateTag(updatedTag);
      ref.invalidate(allTagsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tag updated!')),
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

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Tag'),
          content: Text('Are you sure you want to delete "${widget.tag.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (widget.tag.id != null) {
                  final db = ref.read(databaseProvider);
                  await db.deleteTag(widget.tag.id!);
                  ref.invalidate(allTagsProvider);

                  if (mounted) {
                    Navigator.pop(dialogContext); // Close dialog
                    Navigator.pop(context); // Close edit screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tag deleted')),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
