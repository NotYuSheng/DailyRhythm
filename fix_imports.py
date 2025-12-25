#!/usr/bin/env python3
"""
Script to fix imports after refactoring to feature-first architecture
"""
import os
import re
from pathlib import Path

# Define import mappings: old path -> new path
IMPORT_MAPPINGS = {
    # Models
    "from '../models/sleep_entry.dart'": "from '../../data/models/sleep_entry.dart'",
    "from '../models/meal_entry.dart'": "from '../../data/models/meal_entry.dart'",
    "from '../models/exercise_entry.dart'": "from '../../data/models/exercise_entry.dart'",
    "from '../models/metric_data.dart'": "from '../../data/models/metric_data.dart'",
    "from '../models/tag.dart'": "from '../../data/models/tag.dart'",
    "from '../models/mood_entry.dart'": "from '../../../shared/models/mood_entry.dart'",
    "from '../models/activity_entry.dart'": "from '../../../shared/models/activity_entry.dart'",
    "from '../models/task_entry.dart'": "from '../../../shared/models/task_entry.dart'",
    "from '../models/nap_entry.dart'": "from '../../../shared/models/nap_entry.dart'",

    # Services
    "from '../services/providers.dart'": "",  # Will be replaced with specific providers
    "from '../services/database_service.dart'": "from '../../../../shared/services/database/database_service.dart'",
    "from '../services/metrics_service.dart'": "from '../data/services/metrics_service.dart'",

    # Theme
    "from '../theme/app_theme.dart'": "from '../../../../core/theme/app_theme.dart'",
    "from '../../theme/app_theme.dart'": "from '../../core/theme/app_theme.dart'",

    # Screens (relative imports in journal_screen.dart)
    "from 'add_sleep_screen.dart'": "from '../../../sleep/presentation/screens/add_sleep_screen.dart'",
    "from 'add_meal_screen.dart'": "from '../../../meals/presentation/screens/add_meal_screen.dart'",
    "from 'add_exercise_screen.dart'": "from '../../../exercise/presentation/screens/add_exercise_screen.dart'",
    "from 'tags_screen.dart'": "from '../../../tags/presentation/screens/tags_screen.dart'",
}

def calculate_relative_path(from_file, to_file):
    """Calculate relative path from one file to another"""
    from_dir = Path(from_file).parent
    to_path = Path(to_file)

    try:
        rel_path = os.path.relpath(to_path, from_dir)
        # Convert to Dart import format
        if not rel_path.startswith('.'):
            rel_path = './' + rel_path
        return rel_path
    except ValueError:
        return None

def fix_file_imports(filepath):
    """Fix imports in a single file"""
    with open(filepath, 'r') as f:
        content = f.read()

    original_content = content

    # Apply mappings
    for old_import, new_import in IMPORT_MAPPINGS.items():
        if new_import:  # Skip empty replacements for now
            content = content.replace(old_import, new_import)

    # Fix provider imports based on file location
    if 'lib/features/sleep' in filepath:
        content = re.sub(
            r"from ['\"]\.\.\/services\/providers\.dart['\"]",
            "from '../../data/providers/sleep_providers.dart'",
            content
        )
        content = re.sub(
            r"from ['\"]\.\.\/\.\.\/services\/providers\.dart['\"]",
            "from '../../data/providers/sleep_providers.dart'",
            content
        )
    elif 'lib/features/meals' in filepath:
        content = re.sub(
            r"from ['\"]\.\.\/services\/providers\.dart['\"]",
            "from '../../data/providers/meal_providers.dart'",
            content
        )
    elif 'lib/features/exercise' in filepath:
        content = re.sub(
            r"from ['\"]\.\.\/services\/providers\.dart['\"]",
            "from '../../data/providers/exercise_providers.dart'",
            content
        )
    elif 'lib/features/tags' in filepath:
        content = re.sub(
            r"from ['\"]\.\.\/services\/providers\.dart['\"]",
            "from '../../data/providers/tag_providers.dart'",
            content
        )
    elif 'lib/features/journal' in filepath:
        # Journal screen needs multiple providers
        if 'providers.dart' in content:
            # Add all necessary provider imports
            content = re.sub(
                r"import ['\"]\.\.\/services\/providers\.dart['\"];",
                """import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/providers/common_providers.dart';
import '../../../sleep/data/providers/sleep_providers.dart';
import '../../../meals/data/providers/meal_providers.dart';
import '../../../exercise/data/providers/exercise_providers.dart';
import '../../../tags/data/providers/tag_providers.dart';""",
                content
            )

    # Only write if content changed
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

def main():
    lib_dir = Path('lib')
    dart_files = list(lib_dir.glob('**/*.dart'))

    # Only fix files in new structure
    files_to_fix = [
        f for f in dart_files
        if any(x in str(f) for x in ['features/', 'core/', 'shared/'])
    ]

    fixed_count = 0
    for filepath in files_to_fix:
        if fix_file_imports(str(filepath)):
            fixed_count += 1
            print(f"Fixed: {filepath}")

    print(f"\nFixed {fixed_count} files")

if __name__ == '__main__':
    main()
