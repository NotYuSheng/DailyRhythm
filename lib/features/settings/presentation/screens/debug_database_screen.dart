import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../../core/theme/app_theme.dart';

class DebugDatabaseScreen extends ConsumerStatefulWidget {
  const DebugDatabaseScreen({super.key});

  @override
  ConsumerState<DebugDatabaseScreen> createState() => _DebugDatabaseScreenState();
}

class _DebugDatabaseScreenState extends ConsumerState<DebugDatabaseScreen> {
  String _selectedTable = 'sleep_entries';
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;

  final List<String> _tables = [
    'sleep_entries',
    'meal_entries',
    'mood_entries',
    'exercise_entries',
    'task_entries',
    'activity_entries',
    'tags',
    'nap_entries',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final database = await db.database;
      final data = await database.query(_selectedTable, orderBy: 'id DESC', limit: 50);
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Table selector
          Container(
            padding: const EdgeInsets.all(AppTheme.spacePulse3),
            child: DropdownButtonFormField<String>(
              value: _selectedTable,
              decoration: const InputDecoration(
                labelText: 'Select Table',
                border: OutlineInputBorder(),
              ),
              items: _tables.map((table) {
                return DropdownMenuItem(
                  value: table,
                  child: Text(table),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedTable = value);
                  _loadData();
                }
              },
            ),
          ),

          // Data display
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                    ? const Center(child: Text('No data in this table'))
                    : ListView.builder(
                        itemCount: _data.length,
                        padding: const EdgeInsets.all(AppTheme.spacePulse3),
                        itemBuilder: (context, index) {
                          final row = _data[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppTheme.spacePulse3),
                            child: ExpansionTile(
                              title: Text(
                                'ID: ${row['id'] ?? 'N/A'}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: _buildSubtitle(row),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(AppTheme.spacePulse3),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: row.entries.map((entry) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: AppTheme.spacePulse2),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 120,
                                              child: Text(
                                                '${entry.key}:',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                _formatValue(entry.value),
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Stats footer
          Container(
            padding: const EdgeInsets.all(AppTheme.spacePulse3),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Text(
              'Total rows: ${_data.length} (showing last 50)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(Map<String, dynamic> row) {
    if (_selectedTable == 'sleep_entries') {
      final date = row['date'];
      final totalHours = row['totalHours'];
      return Text('Date: $date | Total: ${totalHours ?? 'null'}h');
    } else if (_selectedTable == 'meal_entries') {
      final name = row['name'];
      final price = row['price'];
      return Text('$name - \$$price');
    } else if (_selectedTable == 'tags') {
      final name = row['name'];
      final category = row['category'];
      return Text('$name ($category)');
    }
    return Text('Date: ${row['date'] ?? row['timestamp'] ?? 'N/A'}');
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is String && value.contains('T')) {
      // Might be ISO8601 date
      try {
        final dt = DateTime.parse(value);
        return '${DateFormat('yyyy-MM-dd HH:mm:ss').format(dt)} ($value)';
      } catch (e) {
        return value.toString();
      }
    }
    return value.toString();
  }
}
