import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class StudentComplaintsPage extends StatefulWidget {
  const StudentComplaintsPage({super.key});

  @override
  State<StudentComplaintsPage> createState() =>
      _StudentComplaintsPageState();
}

class _StudentComplaintsPageState
    extends State<StudentComplaintsPage> {
  final _searchController = TextEditingController();

  late final Stream<List<Map<String, dynamic>>> _complaintsStream;

  String _statusFilter = 'all';

  @override
void initState() {
  super.initState();
  _complaintsStream = ApiService.myComplaintsStream();
}

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openNewComplaint() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _NewComplaintSheet(),
    );

    if (submitted == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _openComplaintDetails(
    Map<String, dynamic> complaint,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ComplaintDetailsSheet(
        complaint: complaint,
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _filterComplaints(
    List<Map<String, dynamic>> complaints,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    return complaints.where((complaint) {
      final status =
          (complaint['status']?.toString() ?? 'open').toLowerCase();

      final matchesStatus =
          _statusFilter == 'all' || status == _statusFilter;

      if (!matchesStatus) return false;

      if (query.isEmpty) return true;

      final title =
          complaint['title']?.toString().toLowerCase() ?? '';

      final description =
          complaint['description']?.toString().toLowerCase() ?? '';

      final category =
          complaint['category']?.toString().toLowerCase() ?? '';

      final priority =
          complaint['priority']?.toString().toLowerCase() ?? '';

      return title.contains(query) ||
          description.contains(query) ||
          category.contains(query) ||
          priority.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _complaintsStream,
      builder: (context, snapshot) {
        final complaints = snapshot.data ?? const [];

        final filtered = _filterComplaints(complaints);

        final total = complaints.length;

        final open = complaints
            .where(
              (c) =>
                  (c['status']?.toString() ?? 'open') == 'open',
            )
            .length;

        final inProgress = complaints
            .where(
              (c) =>
                  (c['status']?.toString() ?? '') ==
                  'in_progress',
            )
            .length;

        final resolved = complaints
            .where(
              (c) {
                final status =
                    c['status']?.toString() ?? '';
                return status == 'resolved' ||
                    status == 'closed';
              },
            )
            .length;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(context),

              const SizedBox(height: 20),

              _buildSummaryCards(
                context,
                total: total,
                open: open,
                inProgress: inProgress,
                resolved: resolved,
              ),

              const SizedBox(height: 20),

              _buildSearch(),

              const SizedBox(height: 12),

              _buildStatusFilters(),

              const SizedBox(height: 16),

              if (snapshot.connectionState ==
                  ConnectionState.waiting &&
                  !snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                _buildError(snapshot.error)
              else if (complaints.isEmpty)
                _buildEmptyState(context)
              else if (filtered.isEmpty)
                _buildNoResults()
              else
                ...filtered.map(
                  (complaint) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ComplaintCard(
                      complaint: complaint,
                      onTap: () =>
                          _openComplaintDetails(complaint),
                    ),
                  ),
                ),

              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Complaints',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track and manage your hostel complaints',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: _openNewComplaint,
          icon: const Icon(Icons.add),
          label: const Text('New Complaint'),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(
    BuildContext context, {
    required int total,
    required int open,
    required int inProgress,
    required int resolved,
  }) {
    final cards = [
      _SummaryData(
        label: 'Total',
        value: total,
        icon: Icons.receipt_long_outlined,
      ),
      _SummaryData(
        label: 'Open',
        value: open,
        icon: Icons.radio_button_unchecked,
      ),
      _SummaryData(
        label: 'In Progress',
        value: inProgress,
        icon: Icons.build_outlined,
      ),
      _SummaryData(
        label: 'Resolved',
        value: resolved,
        icon: Icons.check_circle_outline,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final crossAxisCount = width >= 1000
            ? 4
            : width >= 650
                ? 2
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                width >= 650 ? 2.5 : 1.7,
          ),
          itemBuilder: (context, index) {
            final item = cards[index];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.icon,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.value.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                          ),
                          Text(
                            item.label,
                            overflow:
                                TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search complaints...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.clear),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    const filters = [
      ('all', 'All'),
      ('open', 'Open'),
      ('in_progress', 'In Progress'),
      ('resolved', 'Resolved'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected =
              _statusFilter == filter.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _statusFilter = filter.$1;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildError(Object? error) {
    final message = error is ApiException
        ? error.message
        : 'Unable to load complaints.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 42,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 40,
        ),
        child: Column(
          children: [
            Icon(
              Icons.support_agent_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No complaints yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'If you have a hostel issue, submit a complaint and track it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openNewComplaint,
              icon: const Icon(Icons.add),
              label: const Text('Submit Complaint'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              'No matching complaints',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Try changing your search or filter.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// SUMMARY DATA
// ============================================================

class _SummaryData {
  const _SummaryData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}


// ============================================================
// COMPLAINT CARD
// ============================================================

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({
    required this.complaint,
    required this.onTap,
  });

  final Map<String, dynamic> complaint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title =
        complaint['title']?.toString() ?? 'Untitled complaint';

    final description =
        complaint['description']?.toString() ?? '';

    final category =
        complaint['category']?.toString() ?? 'Other';

    final priority =
        complaint['priority']?.toString() ?? 'medium';

    final status =
        complaint['status']?.toString() ?? 'open';

    final roomNumber =
        complaint['roomNumber']?.toString() ?? '';

    final id = complaint['_id']?.toString() ??
        complaint['id']?.toString() ??
        '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _ComplaintIcon(
                    category: category,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),

              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.flag_outlined,
                    label: _capitalize(priority),
                  ),
                  if (roomNumber.isNotEmpty)
                    _InfoChip(
                      icon: Icons.meeting_room_outlined,
                      label: 'Room $roomNumber',
                    ),
                  if (id.isNotEmpty)
                    _InfoChip(
                      icon: Icons.tag,
                      label: _shortComplaintId(id),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _formatDate(
                        complaint['updatedAt'] ??
                            complaint['createdAt'],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// NEW COMPLAINT SHEET
// ============================================================

class _NewComplaintSheet extends StatefulWidget {
  const _NewComplaintSheet();

  @override
  State<_NewComplaintSheet> createState() =>
      _NewComplaintSheetState();
}

class _NewComplaintSheetState
    extends State<_NewComplaintSheet> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController =
      TextEditingController();

  String _category = 'Maintenance';
  String _priority = 'medium';
  bool _submitting = false;

  static const categories = [
    'Maintenance',
    'Electrical',
    'Plumbing',
    'Cleaning',
    'Mess / Food',
    'Wi-Fi / Internet',
    'Security',
    'Room',
    'Other',
  ];

  static const priorities = [
    'low',
    'medium',
    'high',
    'urgent',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
  if (_submitting) return;

  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _submitting = true;
  });

  try {
    await ApiService.submitComplaint(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      priority: _priority,
    );

    if (!mounted) return;

    // Successfully submitted → close the bottom sheet.
    Navigator.of(context).pop(true);
  } on ApiException catch (e) {
    if (!mounted) return;

    setState(() {
      _submitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _submitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Failed to submit complaint. Please try again.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'New Complaint',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 6),

              Text(
                'Tell us what needs attention in your hostel.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _titleController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Complaint title',
                  hintText:
                      'e.g. Broken ceiling fan',
                  prefixIcon:
                      Icon(Icons.title_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter a complaint title';
                  }

                  if (value.trim().length < 4) {
                    return 'Title is too short';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration:
                    const InputDecoration(
                  labelText: 'Category',
                  prefixIcon:
                      Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          _category = value;
                        });
                      },
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration:
                    const InputDecoration(
                  labelText: 'Priority',
                  prefixIcon:
                      Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(),
                ),
                items: priorities.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(
                      _capitalize(priority),
                    ),
                  );
                }).toList(),
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          _priority = value;
                        });
                      },
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _descriptionController,
                maxLength: 1000,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText:
                      'Describe the problem clearly...',
                  alignLabelWithHint: true,
                  prefixIcon:
                      Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter a description';
                  }

                  if (value.trim().length < 10) {
                    return 'Please provide more details';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _submitting
                        ? 'Submitting...'
                        : 'Submit Complaint',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// COMPLAINT DETAILS
// ============================================================

class _ComplaintDetailsSheet extends StatefulWidget {
  const _ComplaintDetailsSheet({
    required this.complaint,
  });

  final Map<String, dynamic> complaint;

  @override
  State<_ComplaintDetailsSheet> createState() =>
      _ComplaintDetailsSheetState();
}

class _ComplaintDetailsSheetState
    extends State<_ComplaintDetailsSheet> {
  bool _loadingTimeline = true;
  bool _actionLoading = false;

  String? _timelineError;

  List<Map<String, dynamic>> _timeline =
      const [];

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    final id = _complaintId;

    if (id.isEmpty) {
      setState(() {
        _loadingTimeline = false;
      });
      return;
    }

    try {
      final timeline =
          await ApiService.complaintTimeline(id);

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

  String get _complaintId {
    return widget.complaint['_id']?.toString() ??
        widget.complaint['id']?.toString() ??
        widget.complaint['docId']?.toString() ??
        '';
  }

  String get _status {
    return widget.complaint['status']
            ?.toString()
            .toLowerCase() ??
        'open';
  }

  Future<void> _reopen() async {
    if (_complaintId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reopen complaint?'),
          content: const Text(
            'The issue is still not resolved? '
            'This will reopen the complaint for the admin.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Reopen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      await ApiService.reopenComplaint(
        _complaintId,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complaint reopened successfully',
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
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _rateComplaint() async {
    if (_complaintId.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _RatingDialog(
        complaintId: _complaintId,
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;

    final title =
        complaint['title']?.toString() ?? '';

    final description =
        complaint['description']?.toString() ?? '';

    final category =
        complaint['category']?.toString() ?? 'Other';

    final priority =
        complaint['priority']?.toString() ?? 'medium';

    final roomNumber =
        complaint['roomNumber']?.toString() ?? '';

    final rating = complaint['rating'];

    final canReopen =
        _status == 'resolved' ||
        _status == 'closed';

    final canRate =
        canReopen && rating == null;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Complaint Details'),
          actions: [
            IconButton(
              onPressed: _loadingTimeline
                  ? null
                  : _loadTimeline,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            30,
          ),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
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
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                          ),
                        ),
                        _StatusBadge(
                          status: _status,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon:
                              Icons.category_outlined,
                          label: category,
                        ),
                        _InfoChip(
                          icon:
                              Icons.flag_outlined,
                          label:
                              _capitalize(priority),
                        ),
                        if (roomNumber.isNotEmpty)
                          _InfoChip(
                            icon: Icons
                                .meeting_room_outlined,
                            label:
                                'Room $roomNumber',
                          ),
                      ],
                    ),

                    const Divider(height: 28),

                    _DetailRow(
                      label: 'Complaint ID',
                      value: _complaintId.isEmpty
                          ? 'Unavailable'
                          : _shortComplaintId(
                              _complaintId,
                            ),
                    ),

                    _DetailRow(
                      label: 'Submitted',
                      value: _formatDate(
                        complaint['createdAt'],
                      ),
                    ),

                    _DetailRow(
                      label: 'Last updated',
                      value: _formatDate(
                        complaint['updatedAt'] ??
                            complaint['createdAt'],
                      ),
                    ),

                    if (complaint['resolvedAt'] !=
                        null)
                      _DetailRow(
                        label: 'Resolved',
                        value: _formatDate(
                          complaint['resolvedAt'],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description.isEmpty
                          ? 'No description provided.'
                          : description,
                      style: const TextStyle(
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complaint Timeline',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 18),

                    if (_loadingTimeline)
                      const Center(
                        child:
                            CircularProgressIndicator(),
                      )
                    else if (_timelineError != null)
                      Text(
                        _timelineError!,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      )
                    else if (_timeline.isEmpty)
                      const Text(
                        'No timeline events yet.',
                      )
                    else
                      ..._timeline.asMap().entries.map(
                        (entry) {
                          final index = entry.key;
                          final event = entry.value;

                          return _TimelineItem(
                            event: event,
                            isLast:
                                index ==
                                    _timeline.length -
                                        1,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (rating != null)
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Rating',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _StarDisplay(
                        rating:
                            _asInt(rating),
                      ),
                      if ((complaint['feedback']
                                  ?.toString() ??
                              '')
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          complaint['feedback']
                              .toString(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            if (canReopen)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _actionLoading
                          ? null
                          : _reopen,
                  icon: const Icon(
                    Icons.replay_outlined,
                  ),
                  label:
                      const Text('Reopen Complaint'),
                ),
              ),

            

            if (canRate)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _actionLoading
                          ? null
                          : _rateComplaint,
                  icon: const Icon(
                    Icons.star_outline,
                  ),
                  label:
                      const Text('Rate Resolution'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// RATING DIALOG
// ============================================================

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({
    required this.complaintId,
  });

  final String complaintId;

  @override
  State<_RatingDialog> createState() =>
      _RatingDialogState();
}

class _RatingDialogState
    extends State<_RatingDialog> {
  int _rating = 0;
  bool _loading = false;

  final _feedbackController =
      TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a rating',
          ),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await ApiService.rateComplaint(
        widget.complaintId,
        rating: _rating,
        feedback:
            _feedbackController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thank you for your feedback',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Resolution'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How satisfied are you with the resolution?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) {
                  final star = index + 1;

                  return IconButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _rating = star;
                            });
                          },
                    icon: Icon(
                      star <= _rating
                          ? Icons.star
                          : Icons.star_border,
                      size: 34,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _feedbackController,
              maxLines: 4,
              maxLength: 500,
              decoration:
                  const InputDecoration(
                labelText:
                    'Feedback (optional)',
                hintText:
                    'Tell us about your experience...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Submit Rating'),
        ),
      ],
    );
  }
}


// ============================================================
// TIMELINE ITEM
// ============================================================

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.event,
    required this.isLast,
  });

  final Map<String, dynamic> event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final type =
        event['type']?.toString() ?? '';

    final message =
        event['message']?.toString() ??
            'Complaint updated';

    final status =
        event['status']?.toString();

    final icon = switch (type) {
      'created' => Icons.add_task,
      'status_changed' =>
        Icons.sync_alt,
      'reopened' =>
        Icons.replay_outlined,
      _ => Icons.circle_outlined,
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
              ),
              child: Icon(
                icon,
                size: 19,
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 42,
                color: Colors.grey.shade300,
              ),
          ],
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(
                    event['createdAt'],
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (status != null &&
                    status.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 4,
                    ),
                    child: Text(
                      'Status: ${_capitalize(status)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


// ============================================================
// UI HELPERS
// ============================================================

class _ComplaintIcon extends StatelessWidget {
  const _ComplaintIcon({
    required this.category,
  });

  final String category;

  @override
  Widget build(BuildContext context) {
    IconData icon;

    switch (category.toLowerCase()) {
      case 'electrical':
        icon = Icons.electrical_services_outlined;
        break;
      case 'plumbing':
        icon = Icons.plumbing_outlined;
        break;
      case 'cleaning':
        icon = Icons.cleaning_services_outlined;
        break;
      case 'mess / food':
        icon = Icons.restaurant_outlined;
        break;
      case 'wi-fi / internet':
        icon = Icons.wifi_outlined;
        break;
      case 'security':
        icon = Icons.security_outlined;
        break;
      case 'room':
        icon = Icons.meeting_room_outlined;
        break;
      case 'maintenance':
        icon = Icons.build_outlined;
        break;
      default:
        icon = Icons.report_problem_outlined;
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: Theme.of(context)
            .colorScheme
            .onSecondaryContainer,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized =
        status.toLowerCase();

    final label = switch (normalized) {
      'in_progress' => 'In Progress',
      'resolved' => 'Resolved',
      'closed' => 'Closed',
      _ => 'Open',
    };

    final icon = switch (normalized) {
      'in_progress' =>
        Icons.build_outlined,
      'resolved' =>
        Icons.check_circle_outline,
      'closed' =>
        Icons.lock_outline,
      _ =>
        Icons.radio_button_checked,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _statusColor(
          context,
          normalized,
        ).withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: _statusColor(
              context,
              normalized,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _statusColor(
                context,
                normalized,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarDisplay extends StatelessWidget {
  const _StarDisplay({
    required this.rating,
  });

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) => Icon(
          index < rating
              ? Icons.star
              : Icons.star_border,
          size: 24,
        ),
      ),
    );
  }
}


// ============================================================
// UTILITY FUNCTIONS
// ============================================================

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
      return Colors.grey.shade700;
    default:
      return Theme.of(context)
          .colorScheme
          .primary;
  }
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

String _shortComplaintId(String id) {
  if (id.isEmpty) return 'N/A';

  final short =
      id.length > 8 ? id.substring(0, 8) : id;

  return 'CMP-${short.toUpperCase()}';
}

String _formatDate(dynamic value) {
  final date = _toDateTime(value);

  if (date == null) {
    return 'Date unavailable';
  }

  final local = date.toLocal();

  final day =
      local.day.toString().padLeft(2, '0');

  final month =
      local.month.toString().padLeft(2, '0');

  final year =
      local.year.toString();

  final hour = local.hour % 12 == 0
      ? 12
      : local.hour % 12;

  final minute =
      local.minute.toString().padLeft(2, '0');

  final period =
      local.hour >= 12 ? 'PM' : 'AM';

  return '$day/$month/$year • '
      '$hour:$minute $period';
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) {
    return value;
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(
      value,
    );
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  // Firestore Timestamp without importing cloud_firestore.
  try {
    final dynamic dateValue = value;

    final date = dateValue.toDate();

    if (date is DateTime) {
      return date;
    }
  } catch (_) {
    // Ignore invalid timestamp values.
  }

  return null;
}

int _asInt(dynamic value) {
  if (value is int) return value;

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}