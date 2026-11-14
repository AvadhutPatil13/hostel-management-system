import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class AdminActivityPage extends StatefulWidget {
  const AdminActivityPage({super.key});

  @override
  State<AdminActivityPage> createState() => _AdminActivityPageState();
}

class _AdminActivityPageState extends State<AdminActivityPage> {
  List<Map<String, dynamic>> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await ApiService.adminListActivity();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load activity log: $e';
        _loading = false;
      });
    }
  }

  String _value(dynamic value, {String fallback = '—'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatDate(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return _value(raw);
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity Log',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('Recorded changes made by administrators'),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(_error!),
                trailing: TextButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
              ),
            ),
          if (!_loading && _error == null && _entries.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child:
                    Center(child: Text('No admin activity has been recorded.')),
              ),
            ),
          for (final entry in _entries)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(_iconFor(entry['entity']?.toString() ?? '')),
                ),
                title: Text(
                  _value(entry['description']),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                          'By ${_value(entry['actorName'], fallback: 'Admin')}'),
                      Text(_formatDate(entry['createdAt'])),
                      Text(_value(entry['action'])),
                    ],
                  ),
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String entity) {
    switch (entity.toLowerCase()) {
      case 'student':
        return Icons.person_outline;
      case 'room':
        return Icons.meeting_room_outlined;
      case 'fees':
      case 'fee':
        return Icons.receipt_long_outlined;
      case 'complaint':
        return Icons.report_outlined;
      default:
        return Icons.history;
    }
  }
}
