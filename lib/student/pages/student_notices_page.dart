import 'package:flutter/material.dart';

import '../../config/backend_config.dart';
import '../../services/firebase_service.dart';

class StudentNoticesPage extends StatefulWidget {
  const StudentNoticesPage({super.key});

  @override
  State<StudentNoticesPage> createState() => _StudentNoticesPageState();
}

class _StudentNoticesPageState extends State<StudentNoticesPage> {
  bool _loading = false;

  List<Map<String, dynamic>> _notices = [];

  final Map<String, bool> _readStatus = {};

  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'General',
    'Fees',
    'Mess',
    'Hostel',
    'Maintenance',
    'Academic',
    'Events',
    'Emergency',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  // ---------------------------------------------------------------------------
  // LOAD
  // ---------------------------------------------------------------------------

  Future<void> _loadNotices() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    if (BackendConfig.useFirebase) {
      try {
        final list = await FirebaseService.listNotices();

        if (!mounted) return;

        setState(() {
          _notices = list;
          _loading = false;
        });

        await _loadReadStatuses();

        return;
      } catch (e) {
        debugPrint('Unable to load Firebase notices: $e');

        if (mounted) {
          setState(() {
            _loading = false;
          });
        }

        return;
      }
    }

    // Local fallback
    if (!mounted) return;

    setState(() {
      _notices = [
        {
          'id': 'local-1',
          'title': 'Mess menu update',
          'description':
              'A special dinner will be served on 14 Aug.',
          'category': 'Mess',
          'priority': 'Normal',
          'isPinned': false,
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 3))
              .toIso8601String(),
          'expiresAt': '',
        },
        {
          'id': 'local-2',
          'title': 'Examination leave forms',
          'description':
              'Examination leave forms are due by Friday.',
          'category': 'Academic',
          'priority': 'Important',
          'isPinned': true,
          'createdAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'expiresAt': '',
        },
      ];

      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // LOAD READ STATUS
  // ---------------------------------------------------------------------------

  Future<void> _loadReadStatuses() async {
    if (!BackendConfig.useFirebase) {
      return;
    }

    for (final notice in _notices) {
      final id = notice['id']?.toString() ?? '';

      if (id.isEmpty) {
        continue;
      }

      try {
        final read = await FirebaseService.hasReadNotice(id);

        if (!mounted) return;

        setState(() {
          _readStatus[id] = read;
        });
      } catch (e) {
        debugPrint(
          'Unable to load read status for $id: $e',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // MARK READ
  // ---------------------------------------------------------------------------

  Future<void> _markAsRead(
    Map<String, dynamic> notice,
  ) async {
    final id = notice['id']?.toString() ?? '';

    if (id.isEmpty) {
      return;
    }

    if (_readStatus[id] == true) {
      return;
    }

    if (!BackendConfig.useFirebase) {
      if (!mounted) return;

      setState(() {
        _readStatus[id] = true;
      });

      return;
    }

    try {
      await FirebaseService.markNoticeAsRead(id);

      if (!mounted) return;

      setState(() {
        _readStatus[id] = true;
      });
    } catch (e) {
      debugPrint('Unable to mark notice as read: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // OPEN NOTICE
  // ---------------------------------------------------------------------------

  Future<void> _openNotice(
    Map<String, dynamic> notice,
  ) async {
    await _markAsRead(notice);

    if (!mounted) return;

    final title =
        notice['title']?.toString() ?? '';

    final description =
        notice['description']?.toString() ?? '';

    final category =
        notice['category']?.toString() ?? 'General';

    final priority =
        notice['priority']?.toString() ?? 'Normal';

    final isPinned =
        notice['isPinned'] == true;

    final createdAt =
        notice['createdAt']?.toString() ?? '';

    final expiresAt =
        notice['expiresAt']?.toString() ?? '';

    final priorityColor =
        _priorityColor(priority);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isPinned)
                Icon(
                  Icons.push_pin,
                  color: Colors.amber.shade800,
                ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _buildBadge(
                        priority,
                        priorityColor,
                      ),
                      _buildBadge(
                        category,
                        Colors.blueGrey,
                        icon: _categoryIcon(category),
                      ),
                      if (isPinned)
                        _buildBadge(
                          'Pinned',
                          Colors.amber.shade800,
                          icon: Icons.push_pin,
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (createdAt.isNotEmpty)
                    _buildInfoItem(
                      Icons.access_time,
                      'Published ${_formatDate(createdAt)}',
                    ),

                  if (expiresAt.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoItem(
                      Icons.event,
                      'Expires ${_formatDate(expiresAt)}',
                    ),
                  ],

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'You have read this notice',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

  // ---------------------------------------------------------------------------
  // FILTER
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> get _visibleNotices {
    final now = DateTime.now();

    final result = _notices.where((notice) {
      final expiresAt = DateTime.tryParse(
        notice['expiresAt']?.toString() ?? '',
      );

      // Hide expired notices.
      if (expiresAt != null &&
          expiresAt.isBefore(now)) {
        return false;
      }

      final query =
          _searchQuery.trim().toLowerCase();

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

      final noticeCategory =
          notice['category']?.toString() ?? 'General';

      final matchesCategory =
          _selectedCategory == 'All' ||
          noticeCategory == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    // Pinned → Urgent → Important → Normal → Newest.
    result.sort((a, b) {
      final aPinned = a['isPinned'] == true;
      final bPinned = b['isPinned'] == true;

      if (aPinned != bPinned) {
        return aPinned ? -1 : 1;
      }

      const priorityOrder = {
        'Urgent': 0,
        'Important': 1,
        'Normal': 2,
      };

      final aPriority =
          priorityOrder[a['priority']?.toString()] ?? 2;

      final bPriority =
          priorityOrder[b['priority']?.toString()] ?? 2;

      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }

      final aDate = DateTime.tryParse(
            a['createdAt']?.toString() ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bDate = DateTime.tryParse(
            b['createdAt']?.toString() ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return result;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

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

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return '';
    }

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visibleNotices = _visibleNotices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadNotices,
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

                  _buildSearch(),

                  const SizedBox(height: 12),

                  _buildCategoryFilters(),

                  const SizedBox(height: 20),

                  if (visibleNotices.isEmpty)
                    _buildEmptyState()
                  else
                    ...visibleNotices.map(
                      _buildNoticeCard,
                    ),

                  const SizedBox(height: 30),
                ],
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    final activeCount =
        _visibleNotices.length;

    final unreadCount = _visibleNotices.where((notice) {
      final id = notice['id']?.toString() ?? '';
      return _readStatus[id] != true;
    }).length;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.notifications_active,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
                size: 28,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hostel Notices',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$activeCount active notice'
                    '${activeCount == 1 ? '' : 's'}'
                    '${unreadCount > 0 ? ' • $unreadCount unread' : ''}',
                    style: TextStyle(
                      color: unreadCount > 0
                          ? Colors.red.shade700
                          : Colors.grey.shade600,
                      fontWeight:
                          unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

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
        suffixIcon:
            _searchQuery.isNotEmpty
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

  // ---------------------------------------------------------------------------
  // CATEGORIES
  // ---------------------------------------------------------------------------

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder:
            (context, index) {
          final category =
              _categories[index];

          final selected =
              _selectedCategory ==
                  category;

          return ChoiceChip(
            label: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                if (category != 'All') ...[
                  Icon(
                    _categoryIcon(
                      category,
                    ),
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(category),
              ],
            ),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _selectedCategory =
                    category;
              });
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NOTICE CARD
  // ---------------------------------------------------------------------------

  Widget _buildNoticeCard(
    Map<String, dynamic> notice,
  ) {
    final id =
        notice['id']?.toString() ?? '';

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

    final isRead =
        _readStatus[id] == true;

    final priorityColor =
        _priorityColor(priority);

    return Card(
      margin:
          const EdgeInsets.only(bottom: 14),
      elevation:
          !isRead || isPinned ? 3 : 1,
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: () => _openNotice(notice),
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
                    15,
                    15,
                    15,
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
                          if (!isRead)
                            _buildBadge(
                              'NEW',
                              Colors.green,
                              icon:
                                  Icons.fiber_new,
                            ),

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
                              Colors.amber
                                  .shade800,
                              icon:
                                  Icons.push_pin,
                            ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              priority ==
                                      'Urgent'
                                  ? Colors.red
                                      .shade800
                                  : null,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Text(
                        description,
                        maxLines: 3,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 13),

                      Wrap(
                        spacing: 16,
                        runSpacing: 7,
                        children: [
                          if ((notice[
                                      'createdAt']
                                  ?.toString() ??
                              '')
                              .isNotEmpty)
                            _buildInfoItem(
                              Icons.access_time,
                              'Published ${_formatDate(
                                notice[
                                        'createdAt']
                                    ?.toString(),
                              )}',
                            ),

                          if ((notice[
                                      'expiresAt']
                                  ?.toString() ??
                              '')
                              .isNotEmpty)
                            _buildInfoItem(
                              Icons.event,
                              'Expires ${_formatDate(
                                notice[
                                        'expiresAt']
                                    ?.toString(),
                              )}',
                            ),
                        ],
                      ),

                      if (!isRead) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 15,
                              color:
                                  Colors.green.shade700,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Tap to read',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    Colors.green.shade700,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Padding(
                padding:
                    EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BADGE
  // ---------------------------------------------------------------------------

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
      decoration: BoxDecoration(
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
            const SizedBox(width: 4),
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

  // ---------------------------------------------------------------------------
  // INFO
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // EMPTY
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    final hasSearch =
        _searchQuery.trim().isNotEmpty;

    final hasCategory =
        _selectedCategory != 'All';

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              hasSearch || hasCategory
                  ? Icons.search_off
                  : Icons.notifications_none,
              size: 58,
              color:
                  Colors.grey.shade400,
            ),

            const SizedBox(height: 14),

            Text(
              hasSearch || hasCategory
                  ? 'No matching notices'
                  : 'No notices available',
              style: const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              hasSearch || hasCategory
                  ? 'Try another search or category.'
                  : 'There are currently no active hostel notices.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),

            if (hasSearch ||
                hasCategory) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory =
                        'All';
                  });
                },
                child:
                    const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}