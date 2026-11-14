import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/backend_config.dart';
import '../../services/firebase_service.dart';

class AdminNoticesPage extends StatefulWidget {
  const AdminNoticesPage({super.key});

  @override
  State<AdminNoticesPage> createState() => _AdminNoticesPageState();
}

class _AdminNoticesPageState extends State<AdminNoticesPage> {
  static const String _prefsKey = 'hostel_notices_v2';

  List<Map<String, dynamic>> _notices = [];

  bool _loading = false;
  String _searchQuery = '';
  String _filter = 'All';

  final List<String> _categories = [
    'General',
    'Fees',
    'Mess',
    'Hostel',
    'Maintenance',
    'Academic',
    'Events',
    'Emergency',
  ];

  final List<String> _priorities = [
    'Normal',
    'Important',
    'Urgent',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  // ===========================================================================
  // LOAD NOTICES
  // ===========================================================================

  Future<void> _loadNotices() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    if (BackendConfig.useFirebase) {
      try {
        final list = await FirebaseService.listNotices();

        final firebaseNotices = list.map<Map<String, dynamic>>((e) {
          return {
            'id': e['id']?.toString() ?? '',
            'title': e['title']?.toString() ?? '',
            'description': e['description']?.toString() ?? '',
            'category': e['category']?.toString() ?? 'General',
            'priority': e['priority']?.toString() ?? 'Normal',
            'isPinned': e['isPinned'] == true,
            'createdAt': e['createdAt']?.toString() ?? '',
            'expiresAt': e['expiresAt']?.toString() ?? '',
          };
        }).toList();

        firebaseNotices.sort(_sortNotices);

        if (!mounted) return;

        setState(() {
          _notices = firebaseNotices;
          _loading = false;
        });

        return;
      } catch (e) {
        debugPrint('Firebase notices load failed: $e');
      }
    }

    // -------------------------------------------------------------------------
    // LOCAL FALLBACK
    // -------------------------------------------------------------------------

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);

      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;

        final localNotices = list.map<Map<String, dynamic>>((e) {
          final map = Map<String, dynamic>.from(e);

          return {
            'id': map['id']?.toString() ?? '',
            'title': map['title']?.toString() ?? '',
            'description': map['description']?.toString() ?? '',
            'category': map['category']?.toString() ?? 'General',
            'priority': map['priority']?.toString() ?? 'Normal',
            'isPinned': map['isPinned'] == true,
            'createdAt': map['createdAt']?.toString() ?? '',
            'expiresAt': map['expiresAt']?.toString() ?? '',
          };
        }).toList();

        localNotices.sort(_sortNotices);

        if (!mounted) return;

        setState(() {
          _notices = localNotices;
          _loading = false;
        });

        return;
      }
    } catch (e) {
      debugPrint('Local notices load failed: $e');
    }

    // -------------------------------------------------------------------------
    // SAMPLE DATA
    // -------------------------------------------------------------------------

    if (!mounted) return;

    setState(() {
      _notices = [
        {
          'id': 'sample-1',
          'title': 'Water shutdown',
          'description':
              'Water supply will be suspended on 15 Aug from 10 AM to 2 PM.',
          'category': 'Maintenance',
          'priority': 'Urgent',
          'isPinned': true,
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
          'expiresAt': DateTime.now()
              .add(const Duration(days: 2))
              .toIso8601String(),
        },
        {
          'id': 'sample-2',
          'title': 'Guest room booking',
          'description':
              'Guest rooms are available for family visits this weekend.',
          'category': 'Hostel',
          'priority': 'Normal',
          'isPinned': false,
          'createdAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'expiresAt': '',
        },
      ];

      _loading = false;
    });
  }

  Future<void> _saveLocalNotices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_notices));
  }

  // ===========================================================================
  // SORT
  // ===========================================================================

  int _sortNotices(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aPinned = a['isPinned'] == true;
    final bPinned = b['isPinned'] == true;

    if (aPinned != bPinned) {
      return aPinned ? -1 : 1;
    }

    final priorityOrder = {
      'Urgent': 0,
      'Important': 1,
      'Normal': 2,
    };

    final aPriority = priorityOrder[a['priority']] ?? 2;
    final bPriority = priorityOrder[b['priority']] ?? 2;

    if (aPriority != bPriority) {
      return aPriority.compareTo(bPriority);
    }

    final aDate =
        DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);

    final bDate =
        DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);

    return bDate.compareTo(aDate);
  }

  // ===========================================================================
  // FILTER
  // ===========================================================================

  List<Map<String, dynamic>> get _filteredNotices {
    final query = _searchQuery.trim().toLowerCase();

    final result = _notices.where((notice) {
      final title =
          notice['title']?.toString().toLowerCase() ?? '';

      final description =
          notice['description']?.toString().toLowerCase() ?? '';

      final category =
          notice['category']?.toString().toLowerCase() ?? '';

      final priority =
          notice['priority']?.toString().toLowerCase() ?? '';

      final matchesSearch = query.isEmpty ||
          title.contains(query) ||
          description.contains(query) ||
          category.contains(query) ||
          priority.contains(query);

      final matchesFilter = switch (_filter) {
        'Urgent' => notice['priority'] == 'Urgent',
        'Important' => notice['priority'] == 'Important',
        'Pinned' => notice['isPinned'] == true,
        'Expired' => _isExpired(notice),
        'Active' => !_isExpired(notice),
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();

    result.sort(_sortNotices);

    return result;
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  bool _isExpired(Map<String, dynamic> notice) {
    final expiresAt =
        DateTime.tryParse(notice['expiresAt']?.toString() ?? '');

    if (expiresAt == null) {
      return false;
    }

    return expiresAt.isBefore(DateTime.now());
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Not specified';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return 'Not specified';
    }

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return Colors.red;
      case 'Important':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Fees':
        return Icons.currency_rupee;
      case 'Mess':
        return Icons.restaurant;
      case 'Hostel':
        return Icons.apartment;
      case 'Maintenance':
        return Icons.build;
      case 'Academic':
        return Icons.school;
      case 'Events':
        return Icons.event;
      case 'Emergency':
        return Icons.warning_amber;
      default:
        return Icons.campaign;
    }
  }

  // ===========================================================================
  // ADD / EDIT NOTICE
  // ===========================================================================

  Future<void> _showNoticeDialog({
    Map<String, dynamic>? existing,
  }) async {
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );

    final descriptionController = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();

    String selectedCategory =
        existing?['category']?.toString() ?? 'General';

    String selectedPriority =
        existing?['priority']?.toString() ?? 'Normal';

    bool isPinned = existing?['isPinned'] == true;

    DateTime? expiryDate =
        DateTime.tryParse(existing?['expiresAt']?.toString() ?? '');

    final isEditing = existing != null;

    bool? result;

    try {
      result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      isEditing
                          ? Icons.edit_note
                          : Icons.campaign,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEditing
                          ? 'Edit Notice'
                          : 'Publish New Notice',
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: titleController,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              hintText: 'Enter notice title',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Title is required';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 10),

                          TextFormField(
                            controller: descriptionController,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText:
                                  'Write the complete notice...',
                              border: OutlineInputBorder(),
                              prefixIcon:
                                  Icon(Icons.description),
                              alignLabelWithHint: true,
                            ),
                            minLines: 4,
                            maxLines: 7,
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Description is required';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                              prefixIcon:
                                  Icon(Icons.category),
                            ),
                            items: _categories.map(
                              (category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _categoryIcon(category),
                                        size: 19,
                                      ),
                                      const SizedBox(width: 9),
                                      Text(category),
                                    ],
                                  ),
                                );
                              },
                            ).toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              setDialogState(() {
                                selectedCategory = value;
                              });
                            },
                          ),

                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            value: selectedPriority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(),
                              prefixIcon:
                                  Icon(Icons.priority_high),
                            ),
                            items: _priorities.map(
                              (priority) {
                                return DropdownMenuItem(
                                  value: priority,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration:
                                            BoxDecoration(
                                          color:
                                              _priorityColor(
                                            priority,
                                          ),
                                          shape:
                                              BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(priority),
                                    ],
                                  ),
                                );
                              },
                            ).toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              setDialogState(() {
                                selectedPriority = value;
                              });
                            },
                          ),

                          const SizedBox(height: 10),

                          CheckboxListTile(
                            contentPadding:
                                EdgeInsets.zero,
                            title:
                                const Text('Pin this notice'),
                            subtitle: const Text(
                              'Pinned notices appear at the top.',
                            ),
                            value: isPinned,
                            onChanged: (value) {
                              setDialogState(() {
                                isPinned =
                                    value ?? false;
                              });
                            },
                            secondary: const Icon(
                              Icons.push_pin,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade300,
                              ),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.event,
                              ),
                              title:
                                  const Text('Expiry date'),
                              subtitle: Text(
                                expiryDate == null
                                    ? 'No expiry date'
                                    : _formatDate(
                                        expiryDate!
                                            .toIso8601String(),
                                      ),
                              ),
                              trailing: Wrap(
                                children: [
                                  if (expiryDate != null)
                                    IconButton(
                                      tooltip:
                                          'Clear expiry',
                                      icon: const Icon(
                                        Icons.clear,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          expiryDate =
                                              null;
                                        });
                                      },
                                    ),
                                  IconButton(
                                    tooltip:
                                        'Select expiry date',
                                    icon: const Icon(
                                      Icons
                                          .calendar_month,
                                    ),
                                    onPressed: () async {
                                      final now =
                                          DateTime.now();

                                      final picked =
                                          await showDatePicker(
                                        context: context,
                                        initialDate:
                                            expiryDate ??
                                                now,
                                        firstDate: now,
                                        lastDate: DateTime(
                                          now.year + 5,
                                        ),
                                      );

                                      if (picked != null) {
                                        setDialogState(() {
                                          expiryDate =
                                              DateTime(
                                            picked.year,
                                            picked.month,
                                            picked.day,
                                            23,
                                            59,
                                            59,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext)
                          .pop(false);
                    },
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    icon: Icon(
                      isEditing
                          ? Icons.save
                          : Icons.publish,
                    ),
                    label: Text(
                      isEditing
                          ? 'Save Changes'
                          : 'Publish',
                    ),
                    onPressed: () {
                      if (formKey.currentState
                              ?.validate() ??
                          false) {
                        Navigator.of(dialogContext)
                            .pop(true);
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) {
        return;
      }

      final title = titleController.text.trim();
      final description =
          descriptionController.text.trim();

      await _saveNotice(
        existing: existing,
        title: title,
        description: description,
        category: selectedCategory,
        priority: selectedPriority,
        isPinned: isPinned,
        expiresAt:
            expiryDate?.toIso8601String() ?? '',
      );
    } finally {
      // Important:
      // Controllers are disposed ONLY after the dialog has
      // completely finished using them.
      titleController.dispose();
      descriptionController.dispose();
    }
  }

  // ===========================================================================
  // SAVE NOTICE
  // ===========================================================================

  Future<void> _saveNotice({
    Map<String, dynamic>? existing,
    required String title,
    required String description,
    required String category,
    required String priority,
    required bool isPinned,
    required String expiresAt,
  }) async {
    final isEditing = existing != null;

    try {
      if (BackendConfig.useFirebase) {
        if (isEditing) {
          await FirebaseService.updateNotice(
            id: existing!['id'].toString(),
            title: title,
            description: description,
            category: category,
            priority: priority,
            isPinned: isPinned,
            expiresAt: expiresAt,
          );
        } else {
          await FirebaseService.publishNotice(
            title: title,
            description: description,
            category: category,
            priority: priority,
            isPinned: isPinned,
            expiresAt: expiresAt,
          );
        }

        await _loadNotices();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Notice updated successfully'
                  : 'Notice published successfully',
            ),
          ),
        );

        return;
      }

      final now = DateTime.now().toIso8601String();

      if (isEditing) {
        final index = _notices.indexWhere(
          (n) => n['id'] == existing!['id'],
        );

        if (index != -1) {
          setState(() {
            _notices[index] = {
              ..._notices[index],
              'title': title,
              'description': description,
              'category': category,
              'priority': priority,
              'isPinned': isPinned,
              'expiresAt': expiresAt,
            };

            _notices.sort(_sortNotices);
          });
        }
      } else {
        setState(() {
          _notices.insert(0, {
            'id':
                DateTime.now().microsecondsSinceEpoch.toString(),
            'title': title,
            'description': description,
            'category': category,
            'priority': priority,
            'isPinned': isPinned,
            'createdAt': now,
            'expiresAt': expiresAt,
          });

          _notices.sort(_sortNotices);
        });
      }

      await _saveLocalNotices();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Notice updated successfully'
                : 'Notice published successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to save notice: $e',
          ),
        ),
      );
    }
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  Future<void> _removeNotice(
    Map<String, dynamic> notice,
  ) async {
    final title = notice['title']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete notice?'),
          content: Text(
            'Delete "$title"? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final id = notice['id']?.toString() ?? '';

      if (BackendConfig.useFirebase && id.isNotEmpty) {
        await FirebaseService.deleteNotice(id);

        await _loadNotices();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice removed'),
          ),
        );

        return;
      }

      setState(() {
        _notices.removeWhere(
          (n) => n['id'] == notice['id'],
        );
      });

      await _saveLocalNotices();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notice removed'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete notice: $e',
          ),
        ),
      );
    }
  }

  // ===========================================================================
  // PIN / UNPIN
  // ===========================================================================

  Future<void> _togglePin(
    Map<String, dynamic> notice,
  ) async {
    final newValue = !(notice['isPinned'] == true);

    try {
      final id = notice['id']?.toString() ?? '';

      if (BackendConfig.useFirebase && id.isNotEmpty) {
        await FirebaseService.updateNotice(
          id: id,
          title: notice['title']?.toString() ?? '',
          description:
              notice['description']?.toString() ?? '',
          category:
              notice['category']?.toString() ?? 'General',
          priority:
              notice['priority']?.toString() ?? 'Normal',
          isPinned: newValue,
          expiresAt:
              notice['expiresAt']?.toString() ?? '',
        );

        await _loadNotices();
      } else {
        setState(() {
          notice['isPinned'] = newValue;
          _notices.sort(_sortNotices);
        });

        await _saveLocalNotices();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? 'Notice pinned'
                : 'Notice unpinned',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update notice: $e',
          ),
        ),
      );
    }
  }

  // ===========================================================================
  // NOTICE READ ANALYTICS
  // ===========================================================================

  Future<void> _showReadAnalytics(
    Map<String, dynamic> notice,
  ) async {
    final id = notice['id']?.toString() ?? '';

    if (id.isEmpty || id.startsWith('sample-')) {
      _showInfoDialog(
        title: 'Read Analytics',
        message:
            'Read analytics are available for Firebase notices only.',
      );
      return;
    }

    if (!BackendConfig.useFirebase) {
      _showInfoDialog(
        title: 'Read Analytics',
        message:
            'Read analytics are available when Firebase is enabled.',
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const AlertDialog(
          content: SizedBox(
            height: 110,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading read analytics...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final readSnapshot = await FirebaseFirestore.instance
          .collection('notices')
          .doc(id)
          .collection('readBy')
          .get();

      final studentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      final totalStudents = studentSnapshot.docs.length;
      final readCount = readSnapshot.docs.length;

      final percentage = totalStudents == 0
          ? 0.0
          : (readCount / totalStudents) * 100;

      if (!mounted) return;

      Navigator.of(context).pop();

      await _showAnalyticsDialog(
        notice: notice,
        readCount: readCount,
        totalStudents: totalStudents,
        percentage: percentage,
        readDocs: readSnapshot.docs,
        studentDocs: studentSnapshot.docs,
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      _showInfoDialog(
        title: 'Analytics Error',
        message:
            'Unable to load notice analytics.\n\n$e',
      );
    }
  }

  Future<void> _showAnalyticsDialog({
    required Map<String, dynamic> notice,
    required int readCount,
    required int totalStudents,
    required double percentage,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> readDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> studentDocs,
  }) async {
    final readIds = readDocs.map((doc) => doc.id).toSet();

    final readStudents = studentDocs
        .where((doc) => readIds.contains(doc.id))
        .toList();

    final unreadStudents = studentDocs
        .where((doc) => !readIds.contains(doc.id))
        .toList();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.analytics_outlined),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Notice Read Analytics'),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            height: 470,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice['title']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 18),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    final cardWidth = width >= 500
                        ? (width - 24) / 3
                        : width;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _buildAnalyticsCard(
                            'Total Students',
                            totalStudents.toString(),
                            Icons.people,
                            Colors.blue,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildAnalyticsCard(
                            'Read',
                            readCount.toString(),
                            Icons.visibility,
                            Colors.green,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildAnalyticsCard(
                            'Read %',
                            '${percentage.toStringAsFixed(1)}%',
                            Icons.percent,
                            Colors.orange,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 22),

                Text(
                  'Student Status',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: ListView(
                    children: [
                      if (readStudents.isNotEmpty)
                        _buildStudentStatusSection(
                          title: 'Read (${readStudents.length})',
                          students: readStudents,
                          read: true,
                        ),

                      if (unreadStudents.isNotEmpty)
                        _buildStudentStatusSection(
                          title:
                              'Not Read (${unreadStudents.length})',
                          students: unreadStudents,
                          read: false,
                        ),

                      if (studentDocs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'No student accounts found.',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentStatusSection({
    required String title,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> students,
    required bool read,
  }) {
    return ExpansionTile(
      initiallyExpanded: false,
      leading: Icon(
        read
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
        color: read ? Colors.green : Colors.grey,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: students.map((doc) {
        final data = doc.data();

        final name =
            data['name']?.toString() ??
                data['fullName']?.toString() ??
                data['studentName']?.toString() ??
                'Student';

        final email =
            data['email']?.toString() ?? '';

        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 17,
            child: Text(
              name.isNotEmpty
                  ? name[0].toUpperCase()
                  : 'S',
            ),
          ),
          title: Text(name),
          subtitle:
              email.isEmpty ? null : Text(email),
          trailing: Icon(
            read
                ? Icons.check_circle
                : Icons.schedule,
            color: read
                ? Colors.green
                : Colors.orange,
            size: 19,
          ),
        );
      }).toList(),
    );
  }

  void _showInfoDialog({
    required String title,
    required String message,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // STATISTICS
  // ===========================================================================

  int get _totalCount => _notices.length;

  int get _urgentCount => _notices
      .where((n) => n['priority'] == 'Urgent')
      .length;

  int get _pinnedCount => _notices
      .where((n) => n['isPinned'] == true)
      .length;

  int get _activeCount => _notices
      .where((n) => !_isExpired(n))
      .length;

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final filteredNotices = _filteredNotices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _loading ? null : _loadNotices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotices,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildStatistics(),
                  const SizedBox(height: 18),
                  _buildSearch(),
                  const SizedBox(height: 12),
                  _buildFilters(),
                  const SizedBox(height: 18),

                  if (filteredNotices.isEmpty)
                    _buildEmptyState()
                  else
                    ...filteredNotices.map(
                      _buildNoticeCard,
                    ),

                  const SizedBox(height: 90),
                ],
              ),
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () => _showNoticeDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Publish Notice'),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Hostel Notices',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Manage announcements and important hostel updates.',
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int columns;

        if (width >= 1000) {
          columns = 4;
        } else if (width >= 650) {
          columns = 2;
        } else {
          columns = 1;
        }

        const spacing = 12.0;

        final itemWidth = columns == 1
            ? width
            : (width -
                    (spacing * (columns - 1))) /
                columns;

        final cards = [
          _buildStatCard(
            'Total Notices',
            _totalCount.toString(),
            Icons.campaign,
          ),
          _buildStatCard(
            'Active',
            _activeCount.toString(),
            Icons.notifications_active,
          ),
          _buildStatCard(
            'Urgent',
            _urgentCount.toString(),
            Icons.priority_high,
          ),
          _buildStatCard(
            'Pinned',
            _pinnedCount.toString(),
            Icons.push_pin,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search notices...',
        prefixIcon:
            const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon:
                    const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      'All',
      'Active',
      'Urgent',
      'Important',
      'Pinned',
      'Expired',
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected =
              _filter == filter;

          return ChoiceChip(
            label: Text(filter),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _filter = filter;
              });
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // NOTICE CARD
  // ===========================================================================

  Widget _buildNoticeCard(
    Map<String, dynamic> notice,
  ) {
    final title =
        notice['title']?.toString() ?? '';

    final description =
        notice['description']?.toString() ?? '';

    final category =
        notice['category']?.toString() ??
            'General';

    final priority =
        notice['priority']?.toString() ??
            'Normal';

    final isPinned =
        notice['isPinned'] == true;

    final expired =
        _isExpired(notice);

    final priorityColor =
        _priorityColor(priority);

    return Card(
      margin:
          const EdgeInsets.only(bottom: 12),
      elevation: 1,
      clipBehavior:
          Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              color: priorityColor,
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  15,
                  8,
                  15,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _buildBadge(
                          priority,
                          priorityColor,
                        ),
                        _buildBadge(
                          category,
                          Colors.blueGrey,
                          icon:
                              _categoryIcon(
                            category,
                          ),
                        ),
                        if (isPinned)
                          _buildBadge(
                            'Pinned',
                            Colors.amber.shade800,
                            icon:
                                Icons.push_pin,
                          ),
                        if (expired)
                          _buildBadge(
                            'Expired',
                            Colors.grey,
                            icon:
                                Icons.timer_off,
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      description,
                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _buildInfoItem(
                          Icons.access_time,
                          'Published ${_formatDate(
                            notice['createdAt']
                                ?.toString(),
                          )}',
                        ),
                        if ((notice['expiresAt']
                                    ?.toString() ??
                                '')
                            .isNotEmpty)
                          _buildInfoItem(
                            Icons.event,
                            'Expires ${_formatDate(
                              notice['expiresAt']
                                  ?.toString(),
                            )}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            PopupMenuButton<String>(
              tooltip:
                  'Notice actions',
              onSelected: (value) {
                switch (value) {
                  case 'analytics':
                    _showReadAnalytics(
                      notice,
                    );
                    break;

                  case 'edit':
                    _showNoticeDialog(
                      existing: notice,
                    );
                    break;

                  case 'pin':
                    _togglePin(notice);
                    break;

                  case 'delete':
                    _removeNotice(notice);
                    break;
                }
              },
              itemBuilder:
                  (context) => [
                const PopupMenuItem(
                  value: 'analytics',
                  child: ListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    leading: Icon(
                      Icons.analytics_outlined,
                    ),
                    title:
                        Text('Read Analytics'),
                  ),
                ),

                const PopupMenuDivider(),

                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    leading:
                        Icon(Icons.edit),
                    title:
                        Text('Edit'),
                  ),
                ),

                PopupMenuItem(
                  value: 'pin',
                  child: ListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    leading: const Icon(
                      Icons.push_pin,
                    ),
                    title: Text(
                      isPinned
                          ? 'Unpin'
                          : 'Pin',
                    ),
                  ),
                ),

                const PopupMenuDivider(),

                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    title: Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BADGE
  // ===========================================================================

  Widget _buildBadge(
    String text,
    Color color, {
    IconData? icon,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(0.1),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              color.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(
                width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String text,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color:
              Colors.grey.shade600,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color:
                Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.notifications_none,
              size: 56,
              color:
                  Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matching notices'
                  : 'No notices yet',
              style:
                  const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search or filter.'
                  : 'Publish your first hostel notice.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    () => _showNoticeDialog(),
                icon:
                    const Icon(Icons.add),
                label:
                    const Text(
                        'Publish Notice'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}