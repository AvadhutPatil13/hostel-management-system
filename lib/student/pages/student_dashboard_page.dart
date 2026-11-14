import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/backend_config.dart';
import '../../services/api_service.dart';
import '../../services/firebase_service.dart';

import 'student_complaints_page.dart';
import 'student_fees_page.dart';
import 'student_my_room_page.dart';
import 'student_notices_page.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _roomPayload = const {};
  List<Map<String, dynamic>> _complaints = const [];
  List<Map<String, dynamic>> _dues = const [];
  List<Map<String, dynamic>> _notices = const [];

  final Map<String, bool> _noticeReadStatus = {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // ===========================================================================
  // DATA
  // ===========================================================================

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _loadRoom(),
        _loadComplaints(),
        _loadFees(),
        _loadNotices(),
      ]);

      if (!mounted) return;

      setState(() {
        _roomPayload = results[0] as Map<String, dynamic>;
        _complaints =
            results[1] as List<Map<String, dynamic>>;
        _dues =
            results[2] as List<Map<String, dynamic>>;
        _notices =
            results[3] as List<Map<String, dynamic>>;
      });

      await _loadNoticeReadStatuses();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Some dashboard information could not be loaded.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loadRoom() async {
    try {
      final result = await ApiService.myRoom();

      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Dashboard room error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _loadComplaints() async {
    try {
      final result = await ApiService.myComplaints();

      return result
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      debugPrint('Dashboard complaints error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _loadFees() async {
    if (BackendConfig.useFirebase) {
      try {
        final result = await FirebaseService.myDues();

        return result
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      } catch (e) {
        debugPrint('Dashboard fees error: $e');
        return [];
      }
    }

    // Same fallback structure used by StudentFeesPage.
    return [
      {
        'id': 'demo-fee-001',
        'hostelName': 'RIT Boys Hostel',
        'student': 'Student',
        'studentId': 'STU001',
        'room': 'A-101',
        'block': 'Block A',
        'amount': 14500,
        'amountPaid': 5000,
        'remainingAmount': 9500,
        'feeType': 'Hostel Fee',
        'dueDate': '31 Aug 2026',
        'academicYear': '2026-27',
        'feeMonth': 'August 2026',
        'status': 'partial',
        'paymentMethod': 'UPI',
        'paymentReference': 'UPI123456789',
        'lastPaymentAmount': 5000,
        'lastPaymentAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      },
    ];
  }

  Future<List<Map<String, dynamic>>> _loadNotices() async {
    if (BackendConfig.useFirebase) {
      try {
        final result = await FirebaseService.listNotices();

        return result
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      } catch (e) {
        debugPrint('Dashboard notices error: $e');
        return [];
      }
    }

    // Same fallback structure used by StudentNoticesPage.
    return [
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
  }

  Future<void> _loadNoticeReadStatuses() async {
    if (!BackendConfig.useFirebase) {
      for (final notice in _notices) {
        final id = _string(notice['id']);

        if (id.isNotEmpty) {
          _noticeReadStatus[id] = false;
        }
      }

      return;
    }

    for (final notice in _notices) {
      final id = _string(notice['id']);

      if (id.isEmpty) continue;

      try {
        final read = await FirebaseService.hasReadNotice(id);

        if (!mounted) return;

        _noticeReadStatus[id] = read;
      } catch (e) {
        debugPrint(
          'Unable to read notice status for $id: $e',
        );
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  Future<void> _openPage(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );

    if (mounted) {
      _loadDashboard();
    }
  }

  void _goToComplaints() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('My Complaints'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: const StudentComplaintsPage(),
      ),
    ),
  );
}

  void _openFees() {
    _openPage(const StudentFeesPage());
  }

  void _openRoom() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('My Room'),
        ),
        body: const StudentMyRoomPage(),
      ),
    ),
  );
}

  void _openNotices() {
    _openPage(const StudentNoticesPage());
  }

  // ===========================================================================
  // MAP HELPERS
  // ===========================================================================

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const {};
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  String _string(
    dynamic value, {
    String fallback = '',
  }) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? fallback : text;
  }

  int _int(dynamic value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  // ===========================================================================
  // ROOM
  // ===========================================================================

  Map<String, dynamic> get _room {
    return _map(_roomPayload['room']);
  }

  Map<String, dynamic> get _activeCheckin {
    return _map(_roomPayload['activeCheckin']);
  }

  List<Map<String, dynamic>> get _roommates {
    return _maps(_roomPayload['roommates']);
  }

  int get _occupancy {
    return _int(_roomPayload['occupancy']);
  }

  int get _capacity {
    return _int(_room['capacity']);
  }

  bool get _hasRoom => _room.isNotEmpty;

  bool get _isCheckedIn => _activeCheckin.isNotEmpty;

  String get _roomName {
    if (!_hasRoom) return 'Not assigned';

    final building = _string(_room['building']);
    final roomNo = _string(_room['roomNo']);

    final parts = <String>[
      if (building.isNotEmpty) building,
      if (roomNo.isNotEmpty) 'Room $roomNo',
    ];

    return parts.isEmpty
        ? 'Room assigned'
        : parts.join(' • ');
  }

  String get _roomStatus {
    return _string(
      _room['status'],
      fallback: 'Unknown',
    );
  }

  String get _checkInText {
    if (!_isCheckedIn) {
      return 'Currently checked out';
    }

    final value = _activeCheckin['checkInAt'];

    return 'Checked in ${_formatDateTime(value)}';
  }

  // ===========================================================================
  // COMPLAINTS
  // ===========================================================================

  int get _totalComplaints => _complaints.length;

  int get _openComplaints {
    return _complaints.where((complaint) {
      final status = _normalizedStatus(
        complaint['status'],
      );

      return status == 'open';
    }).length;
  }

  int get _inProgressComplaints {
    return _complaints.where((complaint) {
      final status = _normalizedStatus(
        complaint['status'],
      );

      return status == 'in_progress' ||
          status == 'in progress' ||
          status == 'pending';
    }).length;
  }

  int get _resolvedComplaints {
    return _complaints.where((complaint) {
      final status = _normalizedStatus(
        complaint['status'],
      );

      return status == 'resolved' ||
          status == 'closed';
    }).length;
  }

  String _normalizedStatus(dynamic value) {
    return _string(
      value,
      fallback: 'open',
    ).toLowerCase().trim();
  }

  String _complaintTitle(
    Map<String, dynamic> complaint,
  ) {
    return _string(
      complaint['title'],
      fallback: _string(
        complaint['subject'],
        fallback: 'Complaint',
      ),
    );
  }

  String _complaintStatus(
    Map<String, dynamic> complaint,
  ) {
    final raw = _string(
      complaint['status'],
      fallback: 'Open',
    );

    return _prettyStatus(raw);
  }

  String _prettyStatus(String value) {
    final normalized = value
        .replaceAll('_', ' ')
        .trim();

    if (normalized.isEmpty) return 'Unknown';

    return normalized
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  // ===========================================================================
  // FEES
  // ===========================================================================

  int get _totalFee {
    return _dues.fold(
      0,
      (sum, due) => sum + _int(due['amount']),
    );
  }

  int get _totalPaid {
    return _dues.fold(
      0,
      (sum, due) => sum + _int(due['amountPaid']),
    );
  }

  int get _totalRemaining {
    return _dues.fold(
      0,
      (sum, due) => sum + _remainingAmount(due),
    );
  }

  int _remainingAmount(
    Map<String, dynamic> due,
  ) {
    if (due.containsKey('remainingAmount')) {
      final value = _int(due['remainingAmount']);

      return value > 0 ? value : 0;
    }

    final amount = _int(due['amount']);
    final paid = _int(due['amountPaid']);

    final remaining = amount - paid;

    return remaining > 0 ? remaining : 0;
  }

  bool _isOverdue(
    Map<String, dynamic> due,
  ) {
    final remaining = _remainingAmount(due);

    if (remaining <= 0) return false;

    final raw = _string(due['dueDate']);

    if (raw.isEmpty) return false;

    DateTime? dueDate = DateTime.tryParse(raw);

    if (dueDate == null) {
      try {
        dueDate = DateFormat(
          'dd MMM yyyy',
        ).parseStrict(raw);
      } catch (_) {
        return false;
      }
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final normalized = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    );

    return normalized.isBefore(today);
  }

  String _feeStatus(
    Map<String, dynamic> due,
  ) {
    final remaining = _remainingAmount(due);

    if (remaining <= 0) {
      return 'paid';
    }

    if (_isOverdue(due)) {
      return 'overdue';
    }

    final status = _string(
      due['status'],
    ).toLowerCase();

    if (status == 'partial') {
      return 'partial';
    }

    if (_int(due['amountPaid']) > 0) {
      return 'partial';
    }

    return 'pending';
  }

  Map<String, dynamic>? get _importantFee {
    if (_dues.isEmpty) return null;

    final sorted = [..._dues];

    sorted.sort((a, b) {
      final statusOrder = {
        'overdue': 0,
        'pending': 1,
        'partial': 2,
        'paid': 3,
      };

      final aStatus = _feeStatus(a);
      final bStatus = _feeStatus(b);

      final aOrder = statusOrder[aStatus] ?? 4;
      final bOrder = statusOrder[bStatus] ?? 4;

      if (aOrder != bOrder) {
        return aOrder.compareTo(bOrder);
      }

      return _remainingAmount(b)
          .compareTo(_remainingAmount(a));
    });

    return sorted.first;
  }

  // ===========================================================================
  // NOTICES
  // ===========================================================================

  List<Map<String, dynamic>> get _activeNotices {
    final now = DateTime.now();

    final result = _notices.where((notice) {
      final expiresAt = _date(notice['expiresAt']);

      if (expiresAt != null &&
          expiresAt.isBefore(now)) {
        return false;
      }

      return true;
    }).toList();

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
          priorityOrder[_string(a['priority'])] ?? 2;

      final bPriority =
          priorityOrder[_string(b['priority'])] ?? 2;

      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }

      final aDate =
          _date(a['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);

      final bDate =
          _date(b['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return result;
  }

  int get _unreadNotices {
    return _activeNotices.where((notice) {
      final id = _string(notice['id']);

      return id.isNotEmpty &&
          _noticeReadStatus[id] != true;
    }).length;
  }

  // ===========================================================================
  // STUDENT INFO
  // ===========================================================================

  String get _studentName {
    for (final due in _dues) {
      final value = _string(due['student']);

      if (value.isNotEmpty &&
          value.toLowerCase() != 'student') {
        return value;
      }
    }

    for (final complaint in _complaints) {
      final value = _string(
        complaint['studentName'],
      );

      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'Student';
  }

  String get _studentId {
    for (final due in _dues) {
      final value = _string(
        due['studentId'],
      );

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String get _hostelName {
    for (final due in _dues) {
      final value = _string(
        due['hostelName'],
      );

      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'Hostel Management System';
  }

  // ===========================================================================
  // FORMATTING
  // ===========================================================================

  String _money(int amount) {
    return '₹${NumberFormat(
      '#,##0',
      'en_IN',
    ).format(amount)}';
  }

  String _formatDate(dynamic value) {
    final date = _date(value);

    if (date == null) {
      return _string(value, fallback: 'N/A');
    }

    return DateFormat(
      'dd MMM yyyy',
    ).format(date.toLocal());
  }

  String _formatDateTime(dynamic value) {
    final date = _date(value);

    if (date == null) {
      return _string(value, fallback: 'N/A');
    }

    return DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(date.toLocal());
  }

  String _relativeTime(dynamic value) {
    final date = _date(value);

    if (date == null) return '';

    final difference = DateTime.now().difference(
      date.toLocal(),
    );

    if (difference.isNegative) {
      return 'Just now';
    }

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return _formatDate(date);
  }

  // ===========================================================================
  // COLORS / ICONS
  // ===========================================================================

  Color _statusColor(
    BuildContext context,
    String status,
  ) {
    final value = status.toLowerCase();

    if (value.contains('resolved') ||
        value.contains('closed') ||
        value.contains('paid') ||
        value.contains('checked in') ||
        value == 'available') {
      return Colors.green;
    }

    if (value.contains('overdue') ||
        value.contains('urgent') ||
        value.contains('maintenance')) {
      return Colors.red;
    }

    if (value.contains('pending') ||
        value.contains('progress') ||
        value.contains('partial') ||
        value == 'occupied') {
      return Colors.orange;
    }

    return Theme.of(context).colorScheme.primary;
  }

  Color _noticePriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;

      case 'important':
        return Colors.orange;

      default:
        return Colors.blue;
    }
  }

  IconData _noticeIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fees':
        return Icons.currency_rupee;

      case 'mess':
        return Icons.restaurant_outlined;

      case 'hostel':
        return Icons.apartment_outlined;

      case 'maintenance':
        return Icons.build_outlined;

      case 'academic':
        return Icons.school_outlined;

      case 'events':
        return Icons.event_outlined;

      case 'emergency':
        return Icons.warning_amber_rounded;

      default:
        return Icons.campaign_outlined;
    }
  }

  // ===========================================================================
  // UI HELPERS
  // ===========================================================================

  Widget _sectionTitle(
    BuildContext context,
    String title, {
    String? action,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (action != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(action),
          ),
      ],
    );
  }

  Widget _iconContainer(
    BuildContext context,
    IconData icon, {
    Color? color,
    double size = 46,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = color ?? scheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: iconColor,
      ),
    );
  }

  Widget _badge(
    String text,
    Color color, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final firstName = _studentName
        .trim()
        .split(' ')
        .first;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            scheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor:
                    scheme.onPrimary.withValues(alpha: 0.16),
                child: Text(
                  _studentName.isNotEmpty
                      ? _studentName[0].toUpperCase()
                      : 'S',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimary.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.home_work_rounded,
                size: 34,
                color: scheme.onPrimary.withValues(
                  alpha: 0.85,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _hostelName,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_studentId.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Student ID • $_studentId',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimary.withValues(
                  alpha: 0.78,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // OVERVIEW STATS
  // ===========================================================================

  Widget _buildOverview(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width >= 1000
            ? 4
            : width >= 650
                ? 2
                : 2;

        final items = [
          _DashboardStat(
            label: 'Room',
            value: _hasRoom
                ? _string(
                    _room['roomNo'],
                    fallback: 'Assigned',
                  )
                : 'None',
            icon: Icons.meeting_room_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          _DashboardStat(
            label: 'Fee Balance',
            value: _money(_totalRemaining),
            icon: Icons.account_balance_wallet_outlined,
            color: _totalRemaining > 0
                ? Colors.orange
                : Colors.green,
          ),
          _DashboardStat(
            label: 'Open Issues',
            value: '${_openComplaints + _inProgressComplaints}',
            icon: Icons.support_agent_outlined,
            color: _openComplaints > 0 ||
                    _inProgressComplaints > 0
                ? Colors.orange
                : Colors.green,
          ),
          _DashboardStat(
            label: 'New Notices',
            value: '$_unreadNotices',
            icon: Icons.notifications_active_outlined,
            color: _unreadNotices > 0
                ? Colors.red
                : Colors.green,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                width >= 650 ? 2.2 : 1.75,
          ),
          itemBuilder: (context, index) {
            final item = items[index];

            return Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _iconContainer(
                      context,
                      item.icon,
                      color: item.color,
                      size: 44,
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
                            item.label,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.value,
                            maxLines: 1,
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

  // ===========================================================================
  // ROOM SUMMARY
  // ===========================================================================

  Widget _buildRoomSummary(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!_hasRoom) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              _iconContainer(
                context,
                Icons.meeting_room_outlined,
                color: Colors.orange,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No room assigned',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your hostel room assignment is not available.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'My Room',
                onPressed: _openRoom,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final building = _string(
      _room['building'],
      fallback: 'Building',
    );

    final roomNo = _string(
      _room['roomNo'],
      fallback: '—',
    );

    final floor = _string(
      _room['floor'],
      fallback: '—',
    );

    final type = _string(
      _room['type'],
      fallback: '—',
    );

    final roomStatusColor =
        _statusColor(context, _roomStatus);

    final safeCapacity =
        _capacity > 0 ? _capacity : 1;

    final occupancyRatio =
        (_occupancy / safeCapacity)
            .clamp(0.0, 1.0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openRoom,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  _iconContainer(
                    context,
                    Icons.meeting_room_rounded,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$building • Room $roomNo',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$type • Floor $floor',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _badge(
                    _roomStatus,
                    roomStatusColor,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _miniInfo(
                      context,
                      Icons.people_outline,
                      'Occupancy',
                      _capacity > 0
                          ? '$_occupancy / $_capacity'
                          : '$_occupancy',
                    ),
                  ),
                  Expanded(
                    child: _miniInfo(
                      context,
                      _isCheckedIn
                          ? Icons.login_rounded
                          : Icons.logout_rounded,
                      'Status',
                      _isCheckedIn
                          ? 'Checked in'
                          : 'Checked out',
                    ),
                  ),
                  if (_roommates.isNotEmpty)
                    Expanded(
                      child: _miniInfo(
                        context,
                        Icons.group_outlined,
                        'Roommates',
                        '${_roommates.length}',
                      ),
                    ),
                ],
              ),
              if (_capacity > 0) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: occupancyRatio,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(occupancyRatio * 100).round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    _isCheckedIn
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 18,
                    color: _isCheckedIn
                        ? Colors.green
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _checkInText,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniInfo(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // FEE SUMMARY
  // ===========================================================================

  Widget _buildFeeSummary(BuildContext context) {
    final theme = Theme.of(context);
    final fee = _importantFee;

    final progress = _totalFee > 0
        ? (_totalPaid / _totalFee).clamp(0.0, 1.0)
        : 0.0;

    final hasBalance = _totalRemaining > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openFees,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconContainer(
                    context,
                    Icons.account_balance_wallet_outlined,
                    color: hasBalance
                        ? Colors.orange
                        : Colors.green,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fee Overview',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _dues.isEmpty
                              ? 'No fee records available'
                              : '${_dues.length} fee record${_dues.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _openFees,
                    child: const Text('View All'),
                  ),
                ],
              ),
              if (_dues.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _moneyStat(
                        context,
                        'Total',
                        _money(_totalFee),
                      ),
                    ),
                    Expanded(
                      child: _moneyStat(
                        context,
                        'Paid',
                        _money(_totalPaid),
                        color: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _moneyStat(
                        context,
                        'Balance',
                        _money(_totalRemaining),
                        color: hasBalance
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(progress * 100).round()}% paid',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (fee != null &&
                    _remainingAmount(fee) > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: _feeStatus(fee) == 'overdue'
                          ? Colors.red.withValues(alpha: 0.07)
                          : Colors.orange.withValues(alpha: 0.07),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _feeStatus(fee) == 'overdue'
                              ? Icons.warning_amber_rounded
                              : Icons.event_available_outlined,
                          size: 20,
                          color:
                              _feeStatus(fee) == 'overdue'
                                  ? Colors.red
                                  : Colors.orange,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _string(
                                  fee['feeType'],
                                  fallback: 'Fee',
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_money(_remainingAmount(fee))} remaining'
                                '${_string(fee['dueDate']).isNotEmpty ? ' • Due ${_formatDate(fee['dueDate'])}' : ''}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        _badge(
                          _feeStatus(fee).toUpperCase(),
                          _feeStatusColor(
                            _feeStatus(fee),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _moneyStat(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _feeStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;

      case 'partial':
        return Colors.orange;

      case 'overdue':
        return Colors.red;

      default:
        return Colors.blue;
    }
  }

  // ===========================================================================
  // COMPLAINT SUMMARY
  // ===========================================================================

  Widget _buildComplaintSummary(BuildContext context) {
    final theme = Theme.of(context);

    final recent = [..._complaints];

    recent.sort((a, b) {
      final aDate = _date(
        a['createdAt'] ??
            a['updatedAt'],
      );

      final bDate = _date(
        b['createdAt'] ??
            b['updatedAt'],
      );

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    final items = recent.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _iconContainer(
                  context,
                  Icons.support_agent_outlined,
                  color: _openComplaints > 0
                      ? Colors.orange
                      : Colors.green,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complaints',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Track your hostel issues',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _goToComplaints,
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _complaintStat(
                    context,
                    'Open',
                    _openComplaints,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _complaintStat(
                    context,
                    'In Progress',
                    _inProgressComplaints,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _complaintStat(
                    context,
                    'Resolved',
                    _resolvedComplaints,
                    Colors.green,
                  ),
                ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 6),
              ...items.asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final complaint = entry.value;

                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _iconContainer(
                          context,
                          Icons.report_problem_outlined,
                          size: 40,
                        ),
                        title: Text(
                          _complaintTitle(complaint),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          _complaintStatus(complaint),
                          style: TextStyle(
                            color: _statusColor(
                              context,
                              _complaintStatus(complaint),
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                        ),
                        onTap: _goToComplaints,
                      ),
                      if (index != items.length - 1)
                        const Divider(height: 1),
                    ],
                  );
                },
              ),
            ],
            if (_complaints.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.only(top: 18),
                child: _emptyInline(
                  context,
                  Icons.check_circle_outline_rounded,
                  'No complaints',
                  'You currently have no complaints.',
                  Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _complaintStat(
    BuildContext context,
    String label,
    int value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall,
        ),
      ],
    );
  }

  // ===========================================================================
  // NOTICES
  // ===========================================================================

  Widget _buildNoticeSummary(BuildContext context) {
    final theme = Theme.of(context);

    final notices = _activeNotices.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _iconContainer(
                  context,
                  Icons.notifications_active_outlined,
                  color: _unreadNotices > 0
                      ? Colors.red
                      : Colors.green,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hostel Notices',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _unreadNotices > 0
                            ? '$_unreadNotices unread notice${_unreadNotices == 1 ? '' : 's'}'
                            : 'You are all caught up',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _unreadNotices > 0
                              ? Colors.red
                              : Colors.green,
                          fontWeight:
                              _unreadNotices > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openNotices,
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (notices.isEmpty)
              _emptyInline(
                context,
                Icons.notifications_none_rounded,
                'No active notices',
                'There are currently no active hostel notices.',
                Colors.grey,
              )
            else
              ...notices.asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final notice = entry.value;

                  final id = _string(notice['id']);
                  final isUnread =
                      _noticeReadStatus[id] != true;

                  final priority = _string(
                    notice['priority'],
                    fallback: 'Normal',
                  );

                  final category = _string(
                    notice['category'],
                    fallback: 'General',
                  );

                  final priorityColor =
                      _noticePriorityColor(priority);

                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _iconContainer(
                              context,
                              _noticeIcon(category),
                              color: priorityColor,
                              size: 42,
                            ),
                            if (isUnread)
                              Positioned(
                                right: -1,
                                top: -1,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          _string(
                            notice['title'],
                            fallback: 'Notice',
                          ),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${priority == 'Normal' ? category : priority}'
                          '${_string(notice['createdAt']).isNotEmpty ? ' • ${_relativeTime(notice['createdAt'])}' : ''}',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                        ),
                        onTap: _openNotices,
                      ),
                      if (index != notices.length - 1)
                        const Divider(height: 1),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyInline(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // QUICK ACTIONS
  // ===========================================================================

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _DashboardAction(
        title: 'My Room',
        subtitle: 'Room & stay',
        icon: Icons.meeting_room_outlined,
        onTap: _openRoom,
      ),
      _DashboardAction(
        title: 'Fees',
        subtitle: 'Payments & dues',
        icon: Icons.payments_outlined,
        onTap: _openFees,
      ),
      _DashboardAction(
        title: 'Complaints',
        subtitle: 'Report an issue',
        icon: Icons.support_agent_outlined,
        onTap: _goToComplaints,
      ),
      _DashboardAction(
        title: 'Notices',
        subtitle: 'Hostel updates',
        icon: Icons.notifications_none_rounded,
        onTap: _openNotices,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width >= 900
            ? 4
            : width >= 550
                ? 2
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                width >= 550 ? 2.8 : 1.8,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];

            return Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: action.onTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      _iconContainer(
                        context,
                        action.icon,
                        size: 44,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              action.title,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              action.subtitle,
                              maxLines: 1,
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
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unable to load some dashboard data',
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _error ?? 'Please try again.',
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Retry',
              onPressed: _loading
                  ? null
                  : _loadDashboard,
              icon: Icon(
                Icons.refresh_rounded,
                color: scheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _loading
                ? null
                : _loadDashboard,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            40,
          ),
          children: [
            _buildHeader(context),

            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.only(
                  bottom: 16,
                ),
                child: LinearProgressIndicator(),
              ),

            if (_error != null) ...[
              _buildError(context),
              const SizedBox(height: 16),
            ],

            _buildOverview(context),

            const SizedBox(height: 20),

            _sectionTitle(
              context,
              'My Room',
              action: 'View Details',
              onAction: _openRoom,
            ),

            const SizedBox(height: 10),

            _buildRoomSummary(context),

            const SizedBox(height: 20),

            _sectionTitle(
              context,
              'Fees',
              action: 'View All',
              onAction: _openFees,
            ),

            const SizedBox(height: 10),

            _buildFeeSummary(context),

            const SizedBox(height: 20),

            _sectionTitle(
              context,
              'Complaints',
              action: 'View All',
              onAction: _goToComplaints,
            ),

            const SizedBox(height: 10),

            _buildComplaintSummary(context),

            const SizedBox(height: 20),

            _sectionTitle(
              context,
              'Latest Notices',
              action: 'View All',
              onAction: _openNotices,
            ),

            const SizedBox(height: 10),

            _buildNoticeSummary(context),

            const SizedBox(height: 20),

            _sectionTitle(
              context,
              'Quick Actions',
            ),

            const SizedBox(height: 10),

            _buildQuickActions(context),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DASHBOARD STAT
// =============================================================================

class _DashboardStat {
  const _DashboardStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

// =============================================================================
// DASHBOARD ACTION
// =============================================================================

class _DashboardAction {
  const _DashboardAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}