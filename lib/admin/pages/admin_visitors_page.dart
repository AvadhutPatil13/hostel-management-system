import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firebase_service.dart';
import '../../services/api_service.dart';

class AdminVisitorsPage extends StatefulWidget {
  const AdminVisitorsPage({super.key});

  @override
  State<AdminVisitorsPage> createState() =>
      _AdminVisitorsPageState();
}

class _AdminVisitorsPageState extends State<AdminVisitorsPage> {
  bool _loading = true;
  bool _loadingStudents = false;

  List<Map<String, dynamic>> _visitors = [];
  List<Map<String, dynamic>> _students = [];

  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });

    try {
      final results = await Future.wait([
        FirebaseService.listVisitors(),
        FirebaseService.listStudentsForVisitors(),
      ]);

      if (!mounted) return;

      setState(() {
        _visitors =
            List<Map<String, dynamic>>.from(results[0]);
        _students =
            List<Map<String, dynamic>>.from(results[1]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError(_cleanError(e));
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loadingStudents = true;
    });

    try {
      final students =
          await FirebaseService.listStudentsForVisitors();

      if (!mounted) return;

      setState(() {
        _students = students;
        _loadingStudents = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingStudents = false;
      });

      _showError(_cleanError(e));
    }
  }

  // ============================================================
  // FILTERING
  // ============================================================

  List<Map<String, dynamic>> get _filteredVisitors {
    final query = _searchQuery.trim().toLowerCase();

    return _visitors.where((visitor) {
      final status =
          visitor['status']?.toString().toLowerCase() ?? '';

      final visitorName =
          visitor['visitorName']?.toString().toLowerCase() ?? '';

      final visitorPhone =
          visitor['visitorPhone']?.toString().toLowerCase() ?? '';

      final studentName =
          visitor['studentName']?.toString().toLowerCase() ?? '';

      final roomNumber =
          visitor['roomNumber']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          query.isEmpty ||
          visitorName.contains(query) ||
          visitorPhone.contains(query) ||
          studentName.contains(query) ||
          roomNumber.contains(query);

      final matchesStatus =
          _statusFilter == 'all' ||
          status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  // ============================================================
  // ADD VISITOR
  // ============================================================

  Future<void> _showAddVisitorDialog() async {
    await _loadStudents();

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _VisitorFormDialog(
        students: _students,
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  // ============================================================
  // EDIT VISITOR
  // ============================================================

  Future<void> _showEditVisitorDialog(
    Map<String, dynamic> visitor,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _VisitorFormDialog(
        visitor: visitor,
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  // ============================================================
  // CHECKOUT
  // ============================================================

  Future<void> _checkoutVisitor(
    Map<String, dynamic> visitor,
  ) async {
    final id = visitor['id']?.toString() ?? '';

    if (id.isEmpty) {
      _showError('Invalid visitor record.');
      return;
    }

    final confirmed = await _confirm(
      title: 'Check Out Visitor',
      message:
          'Are you sure you want to check out ${visitor['visitorName'] ?? 'this visitor'}?',
      confirmText: 'Check Out',
    );

    if (!confirmed) return;

    try {
      await FirebaseService.checkoutVisitor(id);

      if (!mounted) return;

      _showSuccess('Visitor checked out successfully.');
      await _loadData();
    } catch (e) {
      _showError(_cleanError(e));
    }
  }

  // ============================================================
  // CHECK-IN AGAIN
  // ============================================================

  Future<void> _checkinVisitor(
    Map<String, dynamic> visitor,
  ) async {
    final id = visitor['id']?.toString() ?? '';

    if (id.isEmpty) {
      _showError('Invalid visitor record.');
      return;
    }

    try {
      await FirebaseService.checkinVisitor(id);

      if (!mounted) return;

      _showSuccess('Visitor checked in successfully.');
      await _loadData();
    } catch (e) {
      _showError(_cleanError(e));
    }
  }

  // ============================================================
  // DELETE VISITOR
  // ============================================================

  Future<void> _deleteVisitor(
    Map<String, dynamic> visitor,
  ) async {
    final id = visitor['id']?.toString() ?? '';

    if (id.isEmpty) {
      _showError('Invalid visitor record.');
      return;
    }

    final confirmed = await _confirm(
      title: 'Delete Visitor',
      message:
          'This will permanently delete the visitor record. Continue?',
      confirmText: 'Delete',
      destructive: true,
    );

    if (!confirmed) return;

    try {
      await FirebaseService.removeVisitor(id);

      if (!mounted) return;

      _showSuccess('Visitor record deleted.');
      await _loadData();
    } catch (e) {
      _showError(_cleanError(e));
    }
  }

  // ============================================================
  // VIEW DETAILS
  // ============================================================

  void _showVisitorDetails(
    Map<String, dynamic> visitor,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.badge_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                visitor['visitorName']?.toString() ??
                    'Visitor Details',
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(
                  'Visitor Name',
                  visitor['visitorName'],
                ),
                _detailRow(
                  'Phone',
                  visitor['visitorPhone'],
                ),
                _detailRow(
                  'Purpose',
                  visitor['purpose'],
                ),
                _detailRow(
                  'Student',
                  visitor['studentName'],
                ),
                _detailRow(
                  'Room',
                  _roomDisplay(visitor),
                ),
                _detailRow(
                  'Block',
                  visitor['block'],
                ),
                _detailRow(
                  'Floor',
                  visitor['floor'],
                ),
                _detailRow(
                  'Visit Date',
                  visitor['visitDate'],
                ),
                _detailRow(
                  'Expected Checkout',
                  visitor['expectedCheckout'],
                ),
                _detailRow(
                  'Status',
                  _prettyStatus(
                    visitor['status'],
                  ),
                ),
                _detailRow(
                  'Check-In',
                  _formatDateTime(
                    visitor['checkInAt'],
                  ),
                ),
                _detailRow(
                  'Check-Out',
                  _formatDateTime(
                    visitor['checkOutAt'],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text(
          'Visitors Management',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVisitorDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Visitor'),
      ),
    );
  }

  Widget _buildBody() {
    final visitors = _filteredVisitors;

    final total = _visitors.length;

    final checkedIn = _visitors.where((visitor) {
      return (visitor['status']
                  ?.toString()
                  .toLowerCase() ??
              '') ==
          'checked_in';
    }).length;

    final checkedOut = _visitors.where((visitor) {
      return (visitor['status']
                  ?.toString()
                  .toLowerCase() ??
              '') ==
          'checked_out';
    }).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildHeader(),

        const SizedBox(height: 20),

        _buildStatistics(
          total: total,
          checkedIn: checkedIn,
          checkedOut: checkedOut,
        ),

        const SizedBox(height: 20),

        _buildSearchAndFilters(),

        const SizedBox(height: 20),

        if (visitors.isEmpty)
          _buildEmptyState()
        else
          _buildVisitorList(visitors),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.groups_outlined,
                color: Colors.indigo,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visitor Management',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Register, track and manage hostel visitors.',
                    style: TextStyle(
                      color: Colors.grey,
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

  Widget _buildStatistics({
    required int total,
    required int checkedIn,
    required int checkedOut,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width >= 1100
            ? 3
            : width >= 650
                ? 3
                : 1;

        final cardWidth =
            (width - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: columns == 1 ? width : cardWidth,
              child: _statCard(
                title: 'Total Visitors',
                value: total.toString(),
                icon: Icons.people_alt_outlined,
              ),
            ),
            SizedBox(
              width: columns == 1 ? width : cardWidth,
              child: _statCard(
                title: 'Currently Inside',
                value: checkedIn.toString(),
                icon: Icons.login,
              ),
            ),
            SizedBox(
              width: columns == 1 ? width : cardWidth,
              child: _statCard(
                title: 'Checked Out',
                value: checkedOut.toString(),
                icon: Icons.logout,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
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

  Widget _buildSearchAndFilters() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;

            final search = TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText:
                    'Search visitor, student, phone or room...',
                prefixIcon:
                    const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon:
                            const Icon(Icons.clear),
                      ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            );

            final filter = DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All Visitors'),
                ),
                DropdownMenuItem(
                  value: 'checked_in',
                  child: Text('Checked In'),
                ),
                DropdownMenuItem(
                  value: 'checked_out',
                  child: Text('Checked Out'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _statusFilter = value;
                });
              },
            );

            if (compact) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: 12),
                  filter,
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: search,
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: filter,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVisitorList(
    List<Map<String, dynamic>> visitors,
  ) {
    return Column(
      children: visitors.map((visitor) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _visitorCard(visitor),
        );
      }).toList(),
    );
  }

  Widget _visitorCard(
    Map<String, dynamic> visitor,
  ) {
    final status =
        visitor['status']?.toString().toLowerCase() ??
            'checked_in';

    final isCheckedIn = status == 'checked_in';

    final visitorName =
        visitor['visitorName']?.toString() ??
            'Unknown Visitor';

    final studentName =
        visitor['studentName']?.toString() ??
            'Unknown Student';

    final phone =
        visitor['visitorPhone']?.toString() ?? '';

    final purpose =
        visitor['purpose']?.toString() ?? '';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 750;

            final information = Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 25,
                      child: Text(
                        _initials(visitorName),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  visitorName,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _statusChip(
                                status,
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            phone.isEmpty
                                ? 'Phone not provided'
                                : phone,
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _infoLine(
                  Icons.person_outline,
                  'Visiting Student',
                  studentName,
                ),
                const SizedBox(height: 8),
                _infoLine(
                  Icons.meeting_room_outlined,
                  'Room',
                  _roomDisplay(visitor),
                ),
                const SizedBox(height: 8),
                _infoLine(
                  Icons.description_outlined,
                  'Purpose',
                  purpose.isEmpty
                      ? 'Not specified'
                      : purpose,
                ),
                const SizedBox(height: 8),
                _infoLine(
                  Icons.calendar_today_outlined,
                  'Visit Date',
                  visitor['visitDate']
                          ?.toString() ??
                      '-',
                ),
              ],
            );

            final actions = Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _showVisitorDetails(visitor),
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: const Text('View'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showEditVisitorDialog(visitor),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                  ),
                  label: const Text('Edit'),
                ),
                if (isCheckedIn)
                  FilledButton.icon(
                    onPressed: () =>
                        _checkoutVisitor(visitor),
                    icon: const Icon(
                      Icons.logout,
                      size: 18,
                    ),
                    label: const Text('Check Out'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () =>
                        _checkinVisitor(visitor),
                    icon: const Icon(
                      Icons.login,
                      size: 18,
                    ),
                    label: const Text('Check In'),
                  ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () =>
                      _deleteVisitor(visitor),
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  information,
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 12),
                  actions,
                ],
              );
            }

            return Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: information,
                ),
                const SizedBox(width: 20),
                Flexible(
                  child: actions,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters =
        _searchQuery.isNotEmpty ||
        _statusFilter != 'all';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(50),
        child: Column(
          children: [
            Icon(
              hasFilters
                  ? Icons.search_off
                  : Icons.groups_outlined,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No visitors found'
                  : 'No visitors registered',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try changing your search or filter.'
                  : 'Click "Add Visitor" to register a visitor.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _infoLine(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 9),
        Text(
          '$title: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final checkedIn = status == 'checked_in';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: checkedIn
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _prettyStatus(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: checkedIn
              ? Colors.green.shade700
              : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    dynamic value,
  ) {
    final text =
        value?.toString().trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text.isEmpty ? '-' : text,
            ),
          ),
        ],
      ),
    );
  }

  String _roomDisplay(
    Map<String, dynamic> visitor,
  ) {
    final room =
        visitor['roomNumber']?.toString() ?? '';

    final block =
        visitor['block']?.toString() ?? '';

    if (room.isEmpty && block.isEmpty) {
      return 'Not assigned';
    }

    if (block.isEmpty) {
      return room;
    }

    if (room.isEmpty) {
      return block;
    }

    return '$block - Room $room';
  }

  String _prettyStatus(dynamic value) {
    final status =
        value?.toString() ?? '';

    if (status == 'checked_in') {
      return 'Checked In';
    }

    if (status == 'checked_out') {
      return 'Checked Out';
    }

    if (status.isEmpty) {
      return 'Unknown';
    }

    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String _formatDateTime(dynamic value) {
    final text =
        value?.toString() ?? '';

    if (text.trim().isEmpty) {
      return '-';
    }

    try {
      final date = DateTime.parse(text).toLocal();

      String two(int n) =>
          n.toString().padLeft(2, '0');

      return '${two(date.day)}/${two(date.month)}/${date.year} '
          '${two(date.hour)}:${two(date.minute)}';
    } catch (_) {
      return text;
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'
        .toUpperCase();
  }

  String _cleanError(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    return error
        .toString()
        .replaceFirst('Exception: ', '');
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                  )
                : null,
            onPressed: () =>
                Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result == true;
  }
}

// ============================================================================
// VISITOR FORM DIALOG
// ============================================================================

class _VisitorFormDialog extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final Map<String, dynamic>? visitor;

  const _VisitorFormDialog({
    this.students = const [],
    this.visitor,
  });

  @override
  State<_VisitorFormDialog> createState() =>
      _VisitorFormDialogState();
}

class _VisitorFormDialogState
    extends State<_VisitorFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _purposeController;
  late final TextEditingController _visitDateController;
  late final TextEditingController
      _expectedCheckoutController;

  String? _selectedStudentId;

  bool _saving = false;

  bool get _isEdit => widget.visitor != null;

  @override
  void initState() {
    super.initState();

    final visitor = widget.visitor;

    _nameController = TextEditingController(
      text: visitor?['visitorName']?.toString() ?? '',
    );

    _phoneController = TextEditingController(
      text: visitor?['visitorPhone']?.toString() ?? '',
    );

    _purposeController = TextEditingController(
      text: visitor?['purpose']?.toString() ?? '',
    );

    _visitDateController = TextEditingController(
      text: visitor?['visitDate']?.toString() ??
          _todayString(),
    );

    _expectedCheckoutController =
        TextEditingController(
      text:
          visitor?['expectedCheckout']?.toString() ??
              '',
    );

    _selectedStudentId =
        visitor?['studentId']?.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _purposeController.dispose();
    _visitDateController.dispose();
    _expectedCheckoutController.dispose();
    super.dispose();
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isEdit &&
        (_selectedStudentId == null ||
            _selectedStudentId!.isEmpty)) {
      _showError('Please select a student.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      if (_isEdit) {
        final id =
            widget.visitor!['id']?.toString() ?? '';

        if (id.isEmpty) {
          throw ApiException(
            'Invalid visitor record.',
          );
        }

        await FirebaseService.updateVisitor(
          id,
          visitorName:
              _nameController.text.trim(),
          visitorPhone:
              _phoneController.text.trim(),
          purpose:
              _purposeController.text.trim(),
          visitDate:
              _visitDateController.text.trim(),
          expectedCheckout:
              _expectedCheckoutController.text
                  .trim(),
        );
      } else {
        await FirebaseService.registerVisitor(
          visitorName:
              _nameController.text.trim(),
          visitorPhone:
              _phoneController.text.trim(),
          purpose:
              _purposeController.text.trim(),
          studentId:
              _selectedStudentId!,
          visitDate:
              _visitDateController.text.trim(),
          expectedCheckout:
              _expectedCheckoutController.text
                  .trim(),
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(_cleanError(e));
    }
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _pickVisitDate() async {
    DateTime initialDate = DateTime.now();

    final current =
        _visitDateController.text.trim();

    if (current.isNotEmpty) {
      try {
        initialDate = DateTime.parse(current);
      } catch (_) {}
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null) return;

    _visitDateController.text =
        '${selected.year.toString().padLeft(4, '0')}-'
        '${selected.month.toString().padLeft(2, '0')}-'
        '${selected.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isEdit
                ? Icons.edit_outlined
                : Icons.person_add_alt_1,
          ),
          const SizedBox(width: 10),
          Text(
            _isEdit
                ? 'Edit Visitor'
                : 'Register Visitor',
          ),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Visitor Name',
                  icon: Icons.person_outline,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter visitor name';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                _buildTextField(
                  controller: _phoneController,
                  label: 'Visitor Phone',
                  icon: Icons.phone_outlined,
                  keyboardType:
                      TextInputType.phone,
                ),

                const SizedBox(height: 14),

                _buildTextField(
                  controller:
                      _purposeController,
                  label: 'Purpose of Visit',
                  icon:
                      Icons.description_outlined,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter visit purpose';
                    }

                    return null;
                  },
                ),

                if (!_isEdit) ...[
                  const SizedBox(height: 14),
                  _buildStudentDropdown(),
                ],

                const SizedBox(height: 14),

                TextFormField(
                  controller:
                      _visitDateController,
                  readOnly: true,
                  onTap: _pickVisitDate,
                  decoration:
                      InputDecoration(
                    labelText: 'Visit Date',
                    prefixIcon: const Icon(
                      Icons.calendar_today_outlined,
                    ),
                    suffixIcon: const Icon(
                      Icons.arrow_drop_down,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Select visit date';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                _buildTextField(
                  controller:
                      _expectedCheckoutController,
                  label:
                      'Expected Checkout (optional)',
                  icon:
                      Icons.access_time_outlined,
                  hintText:
                      'Example: 18:30',
                ),

                if (!_isEdit) ...[
                  const SizedBox(height: 16),
                  _buildSelectedStudentPreview(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.pop(
                    context,
                    false,
                  ),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            _saving
                ? 'Saving...'
                : _isEdit
                    ? 'Update'
                    : 'Register',
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildStudentDropdown() {
    if (widget.students.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: Colors.orange,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No students with an active room were found.',
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedStudentId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Visiting Student',
        prefixIcon:
            const Icon(Icons.school_outlined),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),
      items: widget.students.map((student) {
        final id =
            student['id']?.toString() ?? '';

        final name =
            student['name']?.toString() ??
                'Unknown Student';

        final room =
            student['roomNumber']?.toString() ??
                '';

        final block =
            student['block']?.toString() ??
                '';

        final roomText = room.isEmpty
            ? ''
            : block.isEmpty
                ? ' • Room $room'
                : ' • $block / Room $room';

        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            '$name$roomText',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _saving
          ? null
          : (value) {
              setState(() {
                _selectedStudentId = value;
              });
            },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a student';
        }

        return null;
      },
    );
  }

  Widget _buildSelectedStudentPreview() {
    if (_selectedStudentId == null) {
      return const SizedBox.shrink();
    }

    Map<String, dynamic>? student;

    for (final item in widget.students) {
      if (item['id']?.toString() ==
          _selectedStudentId) {
        student = item;
        break;
      }
    }

    if (student == null) {
      return const SizedBox.shrink();
    }

    final name =
        student['name']?.toString() ?? '';

    final room =
        student['roomNumber']?.toString() ?? '';

    final block =
        student['block']?.toString() ?? '';

    final floor =
        student['floor']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.indigo.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Student Room Information',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('Student: $name'),
          Text(
            room.isEmpty
                ? 'Room: Not assigned'
                : 'Room: $room',
          ),
          if (block.isNotEmpty)
            Text('Block: $block'),
          if (floor.isNotEmpty)
            Text('Floor: $floor'),
        ],
      ),
    );
  }

  String _todayString() {
    final now = DateTime.now();

    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _cleanError(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    return error
        .toString()
        .replaceFirst('Exception: ', '');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }
}