import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class AdminComplaintsPage extends StatefulWidget {
  const AdminComplaintsPage({super.key});

  @override
  State<AdminComplaintsPage> createState() =>
      _AdminComplaintsPageState();
}

class _AdminComplaintsPageState
    extends State<AdminComplaintsPage> {
  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _complaints = const [];

  String _searchQuery = '';
  String _statusFilter = 'all';
  String _priorityFilter = 'all';
  String _categoryFilter = 'all';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      final value =
          _searchController.text.trim().toLowerCase();

      if (value == _searchQuery) return;

      setState(() {
        _searchQuery = value;
      });
    });

    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final complaints =
          await ApiService.adminListComplaints();

      if (!mounted) return;

      setState(() {
        _complaints = complaints;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load complaints.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _complaintId(
    Map<String, dynamic> complaint,
  ) {
    return complaint['_id']?.toString() ??
        complaint['id']?.toString() ??
        complaint['docId']?.toString() ??
        '';
  }

  String _status(
    Map<String, dynamic> complaint,
  ) {
    return complaint['status']
            ?.toString()
            .toLowerCase() ??
        'open';
  }

  String _priority(
    Map<String, dynamic> complaint,
  ) {
    return complaint['priority']
            ?.toString()
            .toLowerCase() ??
        'medium';
  }

  String _category(
    Map<String, dynamic> complaint,
  ) {
    final value =
        complaint['category']?.toString().trim();

    return value == null || value.isEmpty
        ? 'Other'
        : value;
  }

  Map<String, dynamic> _user(
    Map<String, dynamic> complaint,
  ) {
    final value = complaint['user'];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const {};
  }

  List<Map<String, dynamic>> get _filteredComplaints {
    return _complaints.where((complaint) {
      final status = _status(complaint);
      final priority = _priority(complaint);
      final category =
          _category(complaint).toLowerCase();

      if (_statusFilter != 'all' &&
          status != _statusFilter) {
        return false;
      }

      if (_priorityFilter != 'all' &&
          priority != _priorityFilter) {
        return false;
      }

      if (_categoryFilter != 'all' &&
          category != _categoryFilter.toLowerCase()) {
        return false;
      }

      if (_searchQuery.isEmpty) {
        return true;
      }

      final user = _user(complaint);

      final searchable = [
        _complaintId(complaint),
        complaint['title'],
        complaint['description'],
        complaint['category'],
        complaint['priority'],
        complaint['status'],
        complaint['roomNumber'],
        complaint['roomId'],
        user['name'],
        user['email'],
        user['phone'],
      ]
          .map(
            (value) =>
                value?.toString().toLowerCase() ?? '',
          )
          .join(' ');

      return searchable.contains(_searchQuery);
    }).toList();
  }

  List<String> get _categories {
    final values = _complaints
        .map(_category)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList();

    values.sort();

    return values;
  }

  int _countByStatus(String status) {
    return _complaints
        .where((complaint) => _status(complaint) == status)
        .length;
  }

  int _countByPriority(String priority) {
    return _complaints
        .where(
          (complaint) =>
              _priority(complaint) == priority,
        )
        .length;
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return 'Open';
    }
  }

  String _priorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High';
      case 'low':
        return 'Low';
      default:
        return 'Medium';
    }
  }

  Color _statusColor(
    BuildContext context,
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return Colors.orange.shade700;
      case 'resolved':
        return Colors.green.shade700;
      case 'closed':
        return Colors.blueGrey.shade700;
      default:
        return Theme.of(context).colorScheme.error;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red.shade900;
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return Icons.pending_actions;
      case 'resolved':
        return Icons.check_circle_outline;
      case 'closed':
        return Icons.lock_outline;
      default:
        return Icons.report_problem_outlined;
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Icons.priority_high;
      case 'high':
        return Icons.keyboard_double_arrow_up;
      case 'low':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.flag_outlined;
    }
  }

  Future<void> _setStatus(
    String id,
    String status,
  ) async {
    if (id.isEmpty) return;

    try {
      await ApiService.adminUpdateComplaintStatus(
        id,
        status,
      );

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complaint status changed to '
            '${_statusLabel(status)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showComplaintDetails(
    Map<String, dynamic> complaint,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AdminComplaintDetailsDialog(
        complaint: complaint,
        onStatusChanged: _setStatus,
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final cardColor =
        color ?? theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color:
                    cardColor.withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: cardColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count.toString(),
                    style: theme
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
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

  Widget _buildStatusChip(
    BuildContext context,
    String status,
  ) {
    final color =
        _statusColor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.12),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(status),
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(
    String priority,
  ) {
    final color =
        _priorityColor(priority);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.12),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _priorityIcon(priority),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            _priorityLabel(priority),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _statusFilter,
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text('All Statuses'),
        ),
        DropdownMenuItem(
          value: 'open',
          child: Text('Open'),
        ),
        DropdownMenuItem(
          value: 'in_progress',
          child: Text('In Progress'),
        ),
        DropdownMenuItem(
          value: 'resolved',
          child: Text('Resolved'),
        ),
        DropdownMenuItem(
          value: 'closed',
          child: Text('Closed'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  Widget _buildPriorityFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _priorityFilter,
      decoration: const InputDecoration(
        labelText: 'Priority',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text('All Priorities'),
        ),
        DropdownMenuItem(
          value: 'urgent',
          child: Text('Urgent'),
        ),
        DropdownMenuItem(
          value: 'high',
          child: Text('High'),
        ),
        DropdownMenuItem(
          value: 'medium',
          child: Text('Medium'),
        ),
        DropdownMenuItem(
          value: 'low',
          child: Text('Low'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _priorityFilter = value;
        });
      },
    );
  }

  Widget _buildCategoryFilter() {
    final categories = _categories;

    final currentExists =
        _categoryFilter == 'all' ||
        categories.any(
          (category) =>
              category.toLowerCase() ==
              _categoryFilter.toLowerCase(),
        );

    final value =
        currentExists ? _categoryFilter : 'all';

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(
          value: 'all',
          child: Text('All Categories'),
        ),
        ...categories.map(
          (category) => DropdownMenuItem(
            value: category,
            child: Text(
              category,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _categoryFilter = value;
        });
      },
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
  ) {
    final complaints =
        _filteredComplaints;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1250,
          child: DataTable(
            columnSpacing: 18,
            headingRowHeight: 52,
            dataRowMinHeight: 76,
            dataRowMaxHeight: 100,
            columns: const [
              DataColumn(
                label: Text('Complaint'),
              ),
              DataColumn(
                label: Text('Student'),
              ),
              DataColumn(
                label: Text('Room'),
              ),
              DataColumn(
                label: Text('Category'),
              ),
              DataColumn(
                label: Text('Priority'),
              ),
              DataColumn(
                label: Text('Status'),
              ),
              DataColumn(
                label: Text('Action'),
              ),
            ],
            rows: complaints.map(
              (complaint) {
                final id =
                    _complaintId(complaint);

                final title =
                    complaint['title']
                            ?.toString() ??
                        'Untitled';

                final user =
                    _user(complaint);

                final name =
                    user['name']
                            ?.toString() ??
                        '';

                final room =
                    complaint['roomNumber']
                            ?.toString() ??
                        '';

                final category =
                    _category(complaint);

                final priority =
                    _priority(complaint);

                final status =
                    _status(complaint);

                final urgent =
                    priority == 'urgent';

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 190,
                        child: Row(
                          children: [
                            if (urgent)
                              Padding(
                                padding:
                                    const EdgeInsets
                                        .only(
                                  right: 7,
                                ),
                                child: Icon(
                                  Icons
                                      .priority_high,
                                  size: 18,
                                  color: Colors
                                      .red
                                      .shade700,
                                ),
                              ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                    ),
                                  ),
                                  Text(
                                    _shortId(id),
                                    style:
                                        TextStyle(
                                      fontSize: 11,
                                      color: Colors
                                          .grey
                                          .shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Text(
                          name.isEmpty
                              ? 'Unknown'
                              : name,
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        room.isEmpty
                            ? '—'
                            : room,
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Text(
                          category,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      _buildPriorityChip(
                        priority,
                      ),
                    ),
                    DataCell(
                      _buildStatusChip(
                        context,
                        status,
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip:
                                'View details',
                            onPressed: () =>
                                _showComplaintDetails(
                                  complaint,
                                ),
                            icon:
                                const Icon(
                              Icons
                                  .visibility_outlined,
                            ),
                          ),
                          PopupMenuButton<
                              String>(
                            tooltip:
                                'Change status',
                            onSelected:
                                _loading
                                    ? null
                                    : (value) {
                                        if (value !=
                                            status) {
                                          _setStatus(
                                            id,
                                            value,
                                          );
                                        }
                                      },
                            itemBuilder:
                                (_) =>
                                    const [
                              PopupMenuItem(
                                value: 'open',
                                child:
                                    Text(
                                  'Open',
                                ),
                              ),
                              PopupMenuItem(
                                value:
                                    'in_progress',
                                child:
                                    Text(
                                  'In Progress',
                                ),
                              ),
                              PopupMenuItem(
                                value:
                                    'resolved',
                                child:
                                    Text(
                                  'Resolved',
                                ),
                              ),
                              PopupMenuItem(
                                value:
                                    'closed',
                                child:
                                    Text(
                                  'Closed',
                                ),
                              ),
                            ],
                            child:
                                const Icon(
                              Icons.more_vert,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCard(
    BuildContext context,
    Map<String, dynamic> complaint,
  ) {
    final id =
        _complaintId(complaint);

    final title =
        complaint['title']?.toString() ??
            'Untitled complaint';

    final description =
        complaint['description']?.toString() ??
            '';

    final user =
        _user(complaint);

    final name =
        user['name']?.toString() ?? '';

    final room =
        complaint['roomNumber']?.toString() ??
            '';

    final category =
        _category(complaint);

    final priority =
        _priority(complaint);

    final status =
        _status(complaint);

    return Card(
      margin:
          const EdgeInsets.only(bottom: 12),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            _showComplaintDetails(
          complaint,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  _buildStatusChip(
                    context,
                    status,
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _buildPriorityChip(
                    priority,
                  ),
                  _InfoChip(
                    icon:
                        Icons.category_outlined,
                    label: category,
                  ),
                  if (room.isNotEmpty)
                    _InfoChip(
                      icon: Icons
                          .meeting_room_outlined,
                      label: 'Room $room',
                    ),
                ],
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(
                  height: 10,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons
                          .person_outline,
                      size: 18,
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Expanded(
                      child: Text(
                        name,
                        overflow:
                            TextOverflow
                                .ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (description
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 10,
                ),
                Text(
                  description,
                  maxLines: 3,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors
                        .grey
                        .shade700,
                  ),
                ),
              ],
              const SizedBox(
                height: 12,
              ),
              Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed: () =>
                          _showComplaintDetails(
                        complaint,
                      ),
                      icon: const Icon(
                        Icons
                            .visibility_outlined,
                      ),
                      label:
                          const Text(
                        'View',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child:
                        DropdownButtonFormField<
                            String>(
                      initialValue:
                          status,
                      decoration:
                          const InputDecoration(
                        contentPadding:
                            EdgeInsets
                                .symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                      items:
                          const [
                        DropdownMenuItem(
                          value: 'open',
                          child:
                              Text(
                            'Open',
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              'in_progress',
                          child:
                              Text(
                            'In Progress',
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              'resolved',
                          child:
                              Text(
                            'Resolved',
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              'closed',
                          child:
                              Text(
                            'Closed',
                          ),
                        ),
                      ],
                      onChanged:
                          _loading
                              ? null
                              : (value) {
                                  if (value !=
                                          null &&
                                      value !=
                                          status) {
                                    _setStatus(
                                      id,
                                      value,
                                    );
                                  }
                                },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final filtered =
        _filteredComplaints;

    final width =
        MediaQuery.sizeOf(context)
            .width;

    final isDesktop =
        width >= 1000;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Complaint Management',
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Review, manage and resolve student complaints',
                      style: TextStyle(
                        color: Colors
                            .grey
                            .shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed:
                    _loading
                        ? null
                        : _load,
                icon: const Icon(
                  Icons.refresh,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          if (_loading)
            const LinearProgressIndicator(),

          if (_error != null) ...[
            const SizedBox(
              height: 12,
            ),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        _error!,
                        style:
                            const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _load,
                      child:
                          const Text(
                        'Retry',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(
            height: 16,
          ),

          LayoutBuilder(
            builder:
                (
                  context,
                  constraints,
                ) {
              final columns =
                  constraints.maxWidth >=
                          1000
                      ? 4
                      : 2;

              final width =
                  columns == 4
                      ? (constraints
                                  .maxWidth -
                              48) /
                          4
                      : (constraints
                                  .maxWidth -
                              16) /
                          2;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child:
                        _buildSummaryCard(
                      context,
                      title: 'Total',
                      count:
                          _complaints
                              .length,
                      icon: Icons
                          .report_problem_outlined,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child:
                        _buildSummaryCard(
                      context,
                      title: 'Open',
                      count:
                          _countByStatus(
                        'open',
                      ),
                      icon: Icons
                          .warning_amber_outlined,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child:
                        _buildSummaryCard(
                      context,
                      title:
                          'In Progress',
                      count:
                          _countByStatus(
                        'in_progress',
                      ),
                      icon: Icons
                          .pending_actions,
                      color:
                          Colors.orange,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child:
                        _buildSummaryCard(
                      context,
                      title:
                          'Resolved',
                      count:
                          _countByStatus(
                        'resolved',
                      ),
                      icon: Icons
                          .check_circle_outline,
                      color:
                          Colors.green,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(
            height: 16,
          ),

          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              child: LayoutBuilder(
                builder:
                    (
                      context,
                      constraints,
                    ) {
                  final narrow =
                      constraints
                              .maxWidth <
                          700;

                  if (narrow) {
                    return Column(
                      children: [
                        _buildSearchField(),
                        const SizedBox(
                          height: 10,
                        ),
                        _buildFilterDropdown(),
                        const SizedBox(
                          height: 10,
                        ),
                        _buildPriorityFilter(),
                        const SizedBox(
                          height: 10,
                        ),
                        _buildCategoryFilter(),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child:
                            _buildSearchField(),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child:
                            _buildFilterDropdown(),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child:
                            _buildPriorityFilter(),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child:
                            _buildCategoryFilter(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Complaints',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall,
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          if (!_loading &&
              _error == null &&
              filtered.isEmpty)
            _buildEmptyState()
          else if (isDesktop)
            _buildDesktopTable(context)
          else
            ...filtered.map(
              (complaint) =>
                  _buildMobileCard(
                context,
                complaint,
              ),
            ),

          const SizedBox(
            height: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller:
          _searchController,
      decoration: InputDecoration(
        labelText:
            'Search complaints',
        hintText:
            'Student, room, title, category...',
        prefixIcon:
            const Icon(Icons.search),
        suffixIcon:
            _searchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController
                          .clear();
                    },
                    icon: const Icon(
                      Icons.clear,
                    ),
                  ),
        border:
            const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters =
        _searchQuery.isNotEmpty ||
        _statusFilter != 'all' ||
        _priorityFilter != 'all' ||
        _categoryFilter != 'all';

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              hasFilters
                  ? Icons.search_off
                  : Icons.inbox_outlined,
              size: 52,
              color: Theme.of(
                context,
              ).colorScheme.outline,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              hasFilters
                  ? 'No complaints match your filters.'
                  : 'No complaints yet.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(
                height: 8,
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchController
                        .clear();
                    _statusFilter =
                        'all';
                    _priorityFilter =
                        'all';
                    _categoryFilter =
                        'all';
                  });
                },
                child: const Text(
                  'Clear filters',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// ============================================================
// ADMIN COMPLAINT DETAILS
// ============================================================

class _AdminComplaintDetailsDialog
    extends StatefulWidget {
  const _AdminComplaintDetailsDialog({
    required this.complaint,
    required this.onStatusChanged,
  });

  final Map<String, dynamic> complaint;

  final Future<void> Function(
    String id,
    String status,
  ) onStatusChanged;

  @override
  State<_AdminComplaintDetailsDialog>
      createState() =>
          _AdminComplaintDetailsDialogState();
}

class _AdminComplaintDetailsDialogState
    extends State<_AdminComplaintDetailsDialog> {
  bool _loadingTimeline = true;
  String? _timelineError;

  List<Map<String, dynamic>> _timeline =
      const [];

  String get _id =>
      widget.complaint['_id']?.toString() ??
      widget.complaint['id']?.toString() ??
      widget.complaint['docId']?.toString() ??
      '';

  String get _status =>
      widget.complaint['status']
          ?.toString()
          .toLowerCase() ??
      'open';

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    if (_id.isEmpty) {
      setState(() {
        _loadingTimeline = false;
        _timelineError =
            'Complaint ID unavailable.';
      });
      return;
    }

    try {
      final timeline =
          await ApiService.adminComplaintTimeline(
        _id,
      );

      if (!mounted) return;

      setState(() {
        _timeline = timeline;
        _timelineError = null;
        _loadingTimeline = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _timelineError = e.message;
        _loadingTimeline = false;
      });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return 'Date unavailable';
    }

    DateTime? date;

    if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    } else if (value is int) {
      date =
          DateTime.fromMillisecondsSinceEpoch(
        value,
      );
    } else {
      try {
        final dynamic timestamp = value;
        final result = timestamp.toDate();

        if (result is DateTime) {
          date = result;
        }
      } catch (_) {}
    }

    if (date == null) {
      return 'Date unavailable';
    }

    final local = date.toLocal();

    final day =
        local.day.toString().padLeft(2, '0');

    final month =
        local.month.toString().padLeft(2, '0');

    final hour =
        local.hour % 12 == 0
            ? 12
            : local.hour % 12;

    final minute =
        local.minute.toString().padLeft(
              2,
              '0',
            );

    final period =
        local.hour >= 12
            ? 'PM'
            : 'AM';

    return '$day/$month/${local.year} • '
        '$hour:$minute $period';
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return 'Open';
    }
  }

  Color _statusColor(
    BuildContext context,
    String status,
  ) {
    switch (status) {
      case 'in_progress':
        return Colors.orange.shade700;
      case 'resolved':
        return Colors.green.shade700;
      case 'closed':
        return Colors.blueGrey.shade700;
      default:
        return Theme.of(
          context,
        ).colorScheme.error;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final complaint =
        widget.complaint;

    final user =
        complaint['user'] is Map
            ? Map<String, dynamic>.from(
                complaint['user'] as Map,
              )
            : const <String, dynamic>{};

    final title =
        complaint['title']?.toString() ??
            'Complaint';

    final description =
        complaint['description']
                ?.toString() ??
            'No description provided.';

    final category =
        complaint['category']
                ?.toString() ??
            'Other';

    final priority =
        complaint['priority']
                ?.toString() ??
            'medium';

    final room =
        complaint['roomNumber']
                ?.toString() ??
            '';

    final name =
        user['name']?.toString() ??
            '';

    final email =
        user['email']?.toString() ??
            '';

    final phone =
        user['phone']?.toString() ??
            '';

    final rating =
        complaint['rating'];

    final feedback =
        complaint['feedback']
                ?.toString() ??
            '';

    final status = _status;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration:
                BoxDecoration(
              color: _statusColor(
                context,
                status,
              ).withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),
            child: Text(
              _statusLabel(status),
              style: TextStyle(
                color: _statusColor(
                  context,
                  status,
                ),
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              _sectionTitle(
                context,
                'Complaint Information',
              ),
              const SizedBox(
                height: 10,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon:
                        Icons.tag,
                    label:
                        _shortId(_id),
                  ),
                  _InfoChip(
                    icon: Icons
                        .category_outlined,
                    label:
                        category,
                  ),
                  _InfoChip(
                    icon: Icons
                        .flag_outlined,
                    label:
                        _capitalize(
                      priority,
                    ),
                  ),
                  if (room.isNotEmpty)
                    _InfoChip(
                      icon: Icons
                          .meeting_room_outlined,
                      label:
                          'Room $room',
                    ),
                ],
              ),

              const Divider(
                height: 28,
              ),

              _sectionTitle(
                context,
                'Student Information',
              ),
              const SizedBox(
                height: 8,
              ),
              if (name.isNotEmpty)
                _detailRow(
                  Icons
                      .person_outline,
                  'Name',
                  name,
                ),
              if (email.isNotEmpty)
                _detailRow(
                  Icons
                      .email_outlined,
                  'Email',
                  email,
                ),
              if (phone.isNotEmpty)
                _detailRow(
                  Icons
                      .phone_outlined,
                  'Phone',
                  phone,
                ),

              const Divider(
                height: 28,
              ),

              _sectionTitle(
                context,
                'Description',
              ),
              const SizedBox(
                height: 10,
              ),
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .all(14),
                decoration:
                    BoxDecoration(
                  color: Theme.of(
                    context,
                  )
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Text(
                  description,
                  style:
                      const TextStyle(
                    height: 1.5,
                  ),
                ),
              ),

              const Divider(
                height: 28,
              ),

              _sectionTitle(
                context,
                'Dates',
              ),
              const SizedBox(
                height: 8,
              ),
              _detailRow(
                Icons
                    .calendar_today_outlined,
                'Submitted',
                _formatDate(
                  complaint[
                      'createdAt'],
                ),
              ),
              _detailRow(
                Icons
                    .update_outlined,
                'Updated',
                _formatDate(
                  complaint[
                          'updatedAt'] ??
                      complaint[
                          'createdAt'],
                ),
              ),
              if (complaint[
                      'resolvedAt'] !=
                  null)
                _detailRow(
                  Icons
                      .check_circle_outline,
                  'Resolved',
                  _formatDate(
                    complaint[
                        'resolvedAt'],
                  ),
                ),

              const Divider(
                height: 28,
              ),

              _sectionTitle(
                context,
                'Update Status',
              ),
              const SizedBox(
                height: 10,
              ),

              DropdownButtonFormField<
                  String>(
                initialValue: status,
                decoration:
                    const InputDecoration(
                  border:
                      OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'open',
                    child:
                        Text('Open'),
                  ),
                  DropdownMenuItem(
                    value:
                        'in_progress',
                    child: Text(
                      'In Progress',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'resolved',
                    child: Text(
                      'Resolved',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'closed',
                    child:
                        Text('Closed'),
                  ),
                ],
                onChanged:
                    (value) async {
                  if (value ==
                          null ||
                      value ==
                          status) {
                    return;
                  }

                  await widget
                      .onStatusChanged(
                    _id,
                    value,
                  );

                  if (!mounted) return;

                  Navigator.pop(
                    context,
                  );
                },
              ),

              const SizedBox(
                height: 24,
              ),

              _sectionTitle(
                context,
                'Complaint Timeline',
              ),
              const SizedBox(
                height: 12,
              ),

              if (_loadingTimeline)
                const Center(
                  child:
                      Padding(
                    padding:
                        EdgeInsets
                            .all(
                      16,
                    ),
                    child:
                        CircularProgressIndicator(),
                  ),
                )
              else if (_timelineError !=
                  null)
                Row(
                  children: [
                    const Icon(
                      Icons
                          .error_outline,
                      color:
                          Colors.red,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child: Text(
                        _timelineError!,
                        style:
                            const TextStyle(
                          color:
                              Colors.red,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _loadTimeline,
                      icon:
                          const Icon(
                        Icons.refresh,
                      ),
                    ),
                  ],
                )
              else if (_timeline
                  .isEmpty)
                const Text(
                  'No timeline events yet.',
                )
              else
                ..._timeline.asMap()
                    .entries
                    .map(
                  (entry) =>
                      _TimelineItem(
                    event:
                        entry.value,
                    isLast:
                        entry.key ==
                            _timeline
                                .length -
                                1,
                    formatDate:
                        _formatDate,
                  ),
                ),

              if (rating != null) ...[
                const Divider(
                  height: 28,
                ),
                _sectionTitle(
                  context,
                  'Student Rating',
                ),
                const SizedBox(
                  height: 8,
                ),
                Row(
                  children:
                      List.generate(
                    5,
                    (index) =>
                        Icon(
                      index <
                              _asInt(
                                rating,
                              )
                          ? Icons.star
                          : Icons
                              .star_border,
                      size: 25,
                    ),
                  ),
                ),
                if (feedback
                    .isNotEmpty) ...[
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    feedback,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(
            context,
          ),
          child:
              const Text('Close'),
        ),
      ],
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title,
  ) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(
            fontWeight:
                FontWeight.bold,
          ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 9,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
          ),
          const SizedBox(
            width: 8,
          ),
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: TextStyle(
                color: Colors
                    .grey
                    .shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// TIMELINE
// ============================================================

class _TimelineItem
    extends StatelessWidget {
  const _TimelineItem({
    required this.event,
    required this.isLast,
    required this.formatDate,
  });

  final Map<String, dynamic> event;
  final bool isLast;
  final String Function(dynamic)
      formatDate;

  @override
  Widget build(
    BuildContext context,
  ) {
    final type =
        event['type']?.toString() ??
            '';

    final message =
        event['message']
                ?.toString() ??
            'Complaint updated';

    final status =
        event['status']?.toString();

    final icon = switch (type) {
      'created' =>
        Icons.add_task,
      'status_changed' =>
        Icons.sync_alt,
      'reopened' =>
        Icons.replay_outlined,
      _ =>
        Icons.circle_outlined,
    };

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: Theme.of(
                  context,
                )
                    .colorScheme
                    .primaryContainer,
              ),
              child: Icon(
                icon,
                size: 18,
                color: Theme.of(
                  context,
                )
                    .colorScheme
                    .onPrimaryContainer,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 42,
                color: Colors
                    .grey
                    .shade300,
              ),
          ],
        ),
        const SizedBox(
          width: 12,
        ),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(
              top: 3,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  message,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  formatDate(
                    event[
                        'createdAt'],
                  ),
                  style:
                      TextStyle(
                    fontSize: 12,
                    color: Colors
                        .grey
                        .shade600,
                  ),
                ),
                if (status != null &&
                    status
                        .isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      top: 4,
                    ),
                    child: Text(
                      'Status: ${_capitalize(status)}',
                      style:
                          TextStyle(
                        fontSize: 12,
                        color: Colors
                            .grey
                            .shade600,
                      ),
                    ),
                  ),
                const SizedBox(
                  height: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


// ============================================================
// SMALL HELPERS
// ============================================================

class _InfoChip
    extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style:
                const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

String _shortId(String id) {
  if (id.isEmpty) return 'N/A';

  final short =
      id.length > 8
          ? id.substring(0, 8)
          : id;

  return 'CMP-${short.toUpperCase()}';
}

String _capitalize(String value) {
  if (value.isEmpty) return value;

  return value
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}'
                '${word.substring(1)}',
      )
      .join(' ');
}

int _asInt(dynamic value) {
  if (value is int) return value;

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}