import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  String _period = 'Monthly';

  DateTime _startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _endDate = DateTime.now();

  String _hostelFilter = 'All';
  String _wingFilter = 'All';
  String _roomFilter = 'All';

  final List<String> _hostels = ['All'];
  final List<String> _wings = ['All'];
  final List<String> _rooms = ['All'];

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _roomsData = [];
  List<Map<String, dynamic>> _checkins = [];
  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _visitors = [];
  List<Map<String, dynamic>> _dues = [];
  List<Map<String, dynamic>> _attendance = [];

  int _totalStudents = 0;
  int _totalRooms = 0;
  int _occupiedRooms = 0;
  int _availableRooms = 0;

  int _totalCheckins = 0;
  int _totalCheckouts = 0;

  int _totalComplaints = 0;
  int _openComplaints = 0;
  int _resolvedComplaints = 0;

  int _totalVisitors = 0;
  int _todayVisitors = 0;

  int _totalAttendance = 0;
  int _presentAttendance = 0;
  int _absentAttendance = 0;

  int _paidDues = 0;
  int _pendingDues = 0;

  double _totalFees = 0;
  double _paidFees = 0;
  double _pendingFees = 0;

  double _occupancy = 0;
  double _attendancePercentage = 0;
  double _feeCollectionPercentage = 0;
  double _complaintResolutionPercentage = 0;

  double _lastMonthFees = 0;
  double _thisMonthFees = 0;

  List<ChartPoint> _occupancyTrend = [];
  List<ChartPoint> _feeTrend = [];
  List<ChartPoint> _complaintTrend = [];
  List<ChartPoint> _visitorTrend = [];

  Map<String, int> _wingOccupied = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  // ============================================================
  // LOAD REPORT DATA
  // ============================================================

  Future<void> _loadReports() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _db.collection('users').get(),
        _db.collection('rooms').get(),
        _db.collection('checkins').get(),
        _db.collection('complaints').get(),
        _db.collection('visitors').get(),
        _db.collection('dues').get(),
        _db.collection('attendance').get(),
      ]);

      _students = _docsToMaps(results[0]);
      _roomsData = _docsToMaps(results[1]);
      _checkins = _docsToMaps(results[2]);
      _complaints = _docsToMaps(results[3]);
      _visitors = _docsToMaps(results[4]);
      _dues = _docsToMaps(results[5]);
      _attendance = _docsToMaps(results[6]);

      _buildFilterValues();
      _calculateReports();

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  List<Map<String, dynamic>> _docsToMaps(
    QuerySnapshot snapshot,
  ) {
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      return {
        ...data,
        '_id': doc.id,
      };
    }).toList();
  }

  String _friendlyError(Object error) {
    if (error.toString().contains('permission-denied')) {
      return 'Firestore permission denied. Check your Firestore rules.';
    }

    return 'Unable to load reports. Please try again.';
  }

  // ============================================================
  // FILTERS
  // ============================================================

  void _buildFilterValues() {
    _hostels
      ..clear()
      ..add('All');

    _wings
      ..clear()
      ..add('All');

    _rooms
      ..clear()
      ..add('All');

    final allData = [
      ..._students,
      ..._roomsData,
      ..._checkins,
      ..._complaints,
      ..._visitors,
      ..._dues,
      ..._attendance,
    ];

    for (final data in allData) {
      final hostel = _firstValue(data, [
        'hostel',
        'hostelName',
        'hostelId',
        'hostel_id',
      ]);

      final wing = _firstValue(data, [
        'wing',
        'wingName',
        'block',
        'blockName',
        'blockId',
      ]);

      final room = _firstValue(data, [
        'room',
        'roomNumber',
        'roomNo',
        'roomId',
        'room_id',
      ]);

      if (hostel != null && hostel.isNotEmpty) {
        if (!_hostels.contains(hostel)) {
          _hostels.add(hostel);
        }
      }

      if (wing != null && wing.isNotEmpty) {
        if (!_wings.contains(wing)) {
          _wings.add(wing);
        }
      }

      if (room != null && room.isNotEmpty) {
        if (!_rooms.contains(room)) {
          _rooms.add(room);
        }
      }
    }

    _hostels.sort();
    _wings.sort();
    _rooms.sort();

    if (!_hostels.contains(_hostelFilter)) {
      _hostelFilter = 'All';
    }

    if (!_wings.contains(_wingFilter)) {
      _wingFilter = 'All';
    }

    if (!_rooms.contains(_roomFilter)) {
      _roomFilter = 'All';
    }
  }

  String? _firstValue(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return null;
  }

  DateTime? _date(
    Map<String, dynamic> data,
  ) {
    final value =
        data['date'] ??
        data['createdAt'] ??
        data['timestamp'] ??
        data['visitDate'] ??
        data['checkInDate'] ??
        data['checkOutDate'];

    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  double _amount(
    Map<String, dynamic> data,
  ) {
    final value =
        data['amount'] ??
        data['totalAmount'] ??
        data['fee'] ??
        data['dueAmount'] ??
        data['total'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString().replaceAll(',', '').replaceAll('₹', '') ?? '',
        ) ??
        0;
  }

  bool _matchesFilters(
    Map<String, dynamic> data,
  ) {
    final hostel = _firstValue(data, [
      'hostel',
      'hostelName',
      'hostelId',
      'hostel_id',
    ]);

    final wing = _firstValue(data, [
      'wing',
      'wingName',
      'block',
      'blockName',
      'blockId',
    ]);

    final room = _firstValue(data, [
      'room',
      'roomNumber',
      'roomNo',
      'roomId',
      'room_id',
    ]);

    if (_hostelFilter != 'All' && hostel != _hostelFilter) {
      return false;
    }

    if (_wingFilter != 'All' && wing != _wingFilter) {
      return false;
    }

    if (_roomFilter != 'All' && room != _roomFilter) {
      return false;
    }

    return true;
  }

  bool _inSelectedPeriod(
    Map<String, dynamic> data,
  ) {
    if (!_matchesFilters(data)) return false;

    final date = _date(data);

    if (date == null) return false;

    final day = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );

    final end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
    );

    return !day.isBefore(start) && !day.isAfter(end);
  }

  // ============================================================
  // REPORT CALCULATIONS
  // ============================================================

  void _calculateReports() {
    final filteredRooms =
        _roomsData.where(_matchesFilters).toList();

    final filteredCheckins =
        _checkins.where(_inSelectedPeriod).toList();

    final filteredComplaints =
        _complaints.where(_inSelectedPeriod).toList();

    final filteredVisitors =
        _visitors.where(_inSelectedPeriod).toList();

    final filteredDues =
        _dues.where(_inSelectedPeriod).toList();

    final filteredAttendance =
        _attendance.where(_inSelectedPeriod).toList();

    _totalStudents = _students
        .where(_matchesFilters)
        .where((data) {
          final role =
              data['role']?.toString().toLowerCase();

          return role == null ||
              role == 'student' ||
              role == 'user' ||
              role == 'resident';
        })
        .length;

    _totalRooms = filteredRooms.length;

    final occupiedIds = <String>{};

    for (final data in filteredCheckins) {
      final status =
          data['status']?.toString().toLowerCase();

      final active =
          status == null ||
          status == 'active' ||
          status == 'checked_in' ||
          status == 'checked-in' ||
          status == 'approved';

      if (!active) continue;

      final room = _firstValue(data, [
        'roomId',
        'room',
        'roomNumber',
        'roomNo',
      ]);

      if (room != null) {
        occupiedIds.add(room);
      }
    }

    _occupiedRooms = occupiedIds.length;

    if (_occupiedRooms == 0) {
      _occupiedRooms = filteredRooms.where((room) {
        final status =
            room['status']?.toString().toLowerCase();

        return room['occupied'] == true ||
            room['isOccupied'] == true ||
            status == 'occupied' ||
            status == 'full';
      }).length;
    }

    if (_occupiedRooms > _totalRooms) {
      _occupiedRooms = _totalRooms;
    }

    _availableRooms =
        _totalRooms - _occupiedRooms;

    _occupancy = _totalRooms == 0
        ? 0
        : _occupiedRooms / _totalRooms * 100;

    _calculateCheckins(filteredCheckins);
    _calculateComplaints(filteredComplaints);
    _calculateVisitors(filteredVisitors);
    _calculateFees(filteredDues);
    _calculateAttendance(filteredAttendance);
    _calculateTrends();
    _calculateWingOccupancy();
    _calculateMonthComparison();
  }

  void _calculateCheckins(
    List<Map<String, dynamic>> data,
  ) {
    _totalCheckins = 0;
    _totalCheckouts = 0;

    for (final item in data) {
      final status =
          item['status']?.toString().toLowerCase();

      final type =
          item['type']?.toString().toLowerCase();

      if (type == 'checkout' ||
          status == 'checked_out' ||
          status == 'checked-out' ||
          item['checkOut'] != null ||
          item['checkOutDate'] != null) {
        _totalCheckouts++;
      } else {
        _totalCheckins++;
      }
    }
  }

  void _calculateComplaints(
    List<Map<String, dynamic>> data,
  ) {
    _totalComplaints = data.length;
    _openComplaints = 0;
    _resolvedComplaints = 0;

    for (final item in data) {
      final status =
          (item['status'] ??
                  item['complaintStatus'])
              ?.toString()
              .toLowerCase();

      if (status == 'resolved' ||
          status == 'closed' ||
          status == 'completed') {
        _resolvedComplaints++;
      } else {
        _openComplaints++;
      }
    }

    _complaintResolutionPercentage =
        _totalComplaints == 0
            ? 0
            : _resolvedComplaints /
                  _totalComplaints *
                  100;
  }

  void _calculateVisitors(
    List<Map<String, dynamic>> data,
  ) {
    _totalVisitors = data.length;

    final now = DateTime.now();

    _todayVisitors = data.where((item) {
      final date = _date(item);

      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
  }

  void _calculateFees(
    List<Map<String, dynamic>> data,
  ) {
    _paidDues = 0;
    _pendingDues = 0;

    _totalFees = 0;
    _paidFees = 0;
    _pendingFees = 0;

    for (final item in data) {
      final amount = _amount(item);

      _totalFees += amount;

      final status =
          (item['status'] ??
                  item['paymentStatus'])
              ?.toString()
              .toLowerCase();

      final paid =
          status == 'paid' ||
          status == 'completed' ||
          status == 'success';

      if (paid) {
        _paidDues++;
        _paidFees += amount;
      } else {
        _pendingDues++;
        _pendingFees += amount;
      }
    }

    _feeCollectionPercentage =
        _totalFees == 0
            ? 0
            : _paidFees / _totalFees * 100;
  }

  void _calculateAttendance(
    List<Map<String, dynamic>> data,
  ) {
    _totalAttendance = data.length;
    _presentAttendance = 0;
    _absentAttendance = 0;

    for (final item in data) {
      final status =
          (item['status'] ??
                  item['attendance'] ??
                  item['present'])
              ?.toString()
              .toLowerCase();

      final present =
          status == 'present' ||
          status == 'p' ||
          status == 'true' ||
          item['present'] == true;

      if (present) {
        _presentAttendance++;
      } else {
        _absentAttendance++;
      }
    }

    _attendancePercentage =
        _totalAttendance == 0
            ? 0
            : _presentAttendance /
                  _totalAttendance *
                  100;
  }

  void _calculateWingOccupancy() {
    _wingOccupied = {};

    for (final room in _roomsData) {
      if (!_matchesFilters(room)) continue;

      final wing = _firstValue(room, [
        'wing',
        'wingName',
        'block',
        'blockName',
      ]);

      if (wing == null) continue;

      final status =
          room['status']?.toString().toLowerCase();

      final occupied =
          room['occupied'] == true ||
          room['isOccupied'] == true ||
          status == 'occupied' ||
          status == 'full';

      if (occupied) {
        _wingOccupied[wing] =
            (_wingOccupied[wing] ?? 0) + 1;
      }
    }
  }

  void _calculateMonthComparison() {
    final now = DateTime.now();

    final thisStart = DateTime(
      now.year,
      now.month,
      1,
    );

    final nextMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    );

    final lastStart = DateTime(
      now.year,
      now.month - 1,
      1,
    );

    _thisMonthFees = 0;
    _lastMonthFees = 0;

    for (final due in _dues) {
      if (!_matchesFilters(due)) continue;

      final date = _date(due);

      if (date == null) continue;

      final amount = _amount(due);

      final status =
          (due['status'] ??
                  due['paymentStatus'])
              ?.toString()
              .toLowerCase();

      final paid =
          status == 'paid' ||
          status == 'completed' ||
          status == 'success';

      if (!paid) continue;

      if (!date.isBefore(thisStart) &&
          date.isBefore(nextMonth)) {
        _thisMonthFees += amount;
      }

      if (!date.isBefore(lastStart) &&
          date.isBefore(thisStart)) {
        _lastMonthFees += amount;
      }
    }
  }

  void _calculateTrends() {
    _occupancyTrend =
        _buildDailyTrend((date) {
      final rooms = _roomsData.where((room) {
        if (!_matchesFilters(room)) return false;

        final roomDate = _date(room);

        return roomDate == null ||
            !roomDate.isAfter(date);
      }).length;

      return rooms == 0
          ? 0
          : _occupiedRooms / rooms * 100;
    });

    _feeTrend =
        _buildDailyTrend((date) {
      double total = 0;

      for (final due in _dues) {
        if (!_matchesFilters(due)) continue;

        final dueDate = _date(due);

        if (dueDate == null) continue;

        if (dueDate.year == date.year &&
            dueDate.month == date.month &&
            dueDate.day == date.day) {
          final status =
              (due['status'] ??
                      due['paymentStatus'])
                  ?.toString()
                  .toLowerCase();

          if (status == 'paid' ||
              status == 'completed' ||
              status == 'success') {
            total += _amount(due);
          }
        }
      }

      return total;
    });

    _complaintTrend =
        _buildDailyTrend((date) {
      return _complaints.where((item) {
        if (!_matchesFilters(item)) return false;

        final itemDate = _date(item);

        return itemDate != null &&
            itemDate.year == date.year &&
            itemDate.month == date.month &&
            itemDate.day == date.day;
      }).length.toDouble();
    });

    _visitorTrend =
        _buildDailyTrend((date) {
      return _visitors.where((item) {
        if (!_matchesFilters(item)) return false;

        final itemDate = _date(item);

        return itemDate != null &&
            itemDate.year == date.year &&
            itemDate.month == date.month &&
            itemDate.day == date.day;
      }).length.toDouble();
    });
  }

  List<ChartPoint> _buildDailyTrend(
    double Function(DateTime) callback,
  ) {
    final result = <ChartPoint>[];

    DateTime current = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );

    final end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
    );

    int safety = 0;

    while (!current.isAfter(end) && safety < 366) {
      result.add(
        ChartPoint(
          current,
          callback(current),
        ),
      );

      current = current.add(
        const Duration(days: 1),
      );

      safety++;
    }

    return result;
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  String _currency(double value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)}Cr';
    }

    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)}L';
    }

    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }

    return '₹${value.toStringAsFixed(0)}';
  }

  String _dateText(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // PERIOD
  // ============================================================

  void _setPeriod(String period) {
    final now = DateTime.now();

    setState(() {
      _period = period;

      if (period == 'Daily') {
        _startDate = DateTime(
          now.year,
          now.month,
          now.day,
        );

        _endDate = _startDate;
      } else if (period == 'Weekly') {
        final weekday = now.weekday;

        _startDate = DateTime(
          now.year,
          now.month,
          now.day - weekday + 1,
        );

        _endDate = now;
      } else if (period == 'Monthly') {
        _startDate = DateTime(
          now.year,
          now.month,
          1,
        );

        _endDate = now;
      }
    });

    _calculateReports();
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
    );

    if (range == null) return;

    setState(() {
      _period = 'Custom';
      _startDate = range.start;
      _endDate = range.end;
    });

    _calculateReports();
  }

  // ============================================================
  // CSV EXPORT
  // ============================================================

  Future<void> _exportCSV() async {
    final rows = <List<String>>[
      ['Hostel Management System - Report'],
      ['Period', '${_dateText(_startDate)} - ${_dateText(_endDate)}'],
      [],
      ['Metric', 'Value'],
      ['Students', '$_totalStudents'],
      ['Total Rooms', '$_totalRooms'],
      ['Occupied Rooms', '$_occupiedRooms'],
      ['Available Rooms', '$_availableRooms'],
      ['Occupancy', '${_occupancy.toStringAsFixed(2)}%'],
      ['Check-ins', '$_totalCheckins'],
      ['Check-outs', '$_totalCheckouts'],
      ['Complaints', '$_totalComplaints'],
      ['Open Complaints', '$_openComplaints'],
      ['Resolved Complaints', '$_resolvedComplaints'],
      ['Visitors', '$_totalVisitors'],
      ['Visitors Today', '$_todayVisitors'],
      ['Attendance', '$_totalAttendance'],
      ['Present', '$_presentAttendance'],
      ['Absent', '$_absentAttendance'],
      [
        'Attendance %',
        '${_attendancePercentage.toStringAsFixed(2)}%',
      ],
      ['Total Fees', _totalFees.toStringAsFixed(2)],
      ['Paid Fees', _paidFees.toStringAsFixed(2)],
      ['Pending Fees', _pendingFees.toStringAsFixed(2)],
      ['Paid Dues', '$_paidDues'],
      ['Pending Dues', '$_pendingDues'],
    ];

    final csv = rows.map((row) {
      return row.map(_csvEscape).join(',');
    }).join('\n');

    _download(
      utf8.encode(csv),
      'hostel_report.csv',
      'text/csv',
    );
  }

  String _csvEscape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }

    return value;
  }

  // ============================================================
  // EXCEL EXPORT
  // ============================================================

  Future<void> _exportExcel() async {
    final excel = Excel.createExcel();

    final sheet = excel['Reports'];

    final rows = [
      ['Hostel Management System - Report'],
      [
        'Period',
        '${_dateText(_startDate)} - ${_dateText(_endDate)}',
      ],
      [],
      ['Metric', 'Value'],
      ['Students', _totalStudents],
      ['Total Rooms', _totalRooms],
      ['Occupied Rooms', _occupiedRooms],
      ['Available Rooms', _availableRooms],
      ['Occupancy', _occupancy],
      ['Check-ins', _totalCheckins],
      ['Check-outs', _totalCheckouts],
      ['Complaints', _totalComplaints],
      ['Open Complaints', _openComplaints],
      ['Resolved Complaints', _resolvedComplaints],
      ['Visitors', _totalVisitors],
      ['Visitors Today', _todayVisitors],
      ['Attendance', _totalAttendance],
      ['Present', _presentAttendance],
      ['Absent', _absentAttendance],
      ['Attendance %', _attendancePercentage],
      ['Total Fees', _totalFees],
      ['Paid Fees', _paidFees],
      ['Pending Fees', _pendingFees],
      ['Paid Dues', _paidDues],
      ['Pending Dues', _pendingDues],
    ];

    for (final row in rows) {
      sheet.appendRow(
        row.map((value) {
          return TextCellValue(value.toString());
        }).toList(),
      );
    }

    final bytes = excel.encode();

    if (bytes == null) return;

    _download(
      bytes,
      'hostel_report.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ============================================================
  // PDF EXPORT
  // ============================================================

  Future<void> _exportPDF() async {
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Text(
              'Hostel Management System',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Administrative Report',
              style: const pw.TextStyle(
                fontSize: 15,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Period: ${_dateText(_startDate)} - ${_dateText(_endDate)}',
            ),
            pw.SizedBox(height: 20),

            pw.Table.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                ['Students', '$_totalStudents'],
                ['Total Rooms', '$_totalRooms'],
                ['Occupied Rooms', '$_occupiedRooms'],
                ['Available Rooms', '$_availableRooms'],
                [
                  'Occupancy',
                  '${_occupancy.toStringAsFixed(1)}%',
                ],
                ['Check-ins', '$_totalCheckins'],
                ['Check-outs', '$_totalCheckouts'],
                ['Complaints', '$_totalComplaints'],
                ['Open Complaints', '$_openComplaints'],
                ['Resolved Complaints', '$_resolvedComplaints'],
                ['Visitors', '$_totalVisitors'],
                ['Visitors Today', '$_todayVisitors'],
                ['Attendance', '$_totalAttendance'],
                ['Present', '$_presentAttendance'],
                ['Absent', '$_absentAttendance'],
                [
                  'Attendance %',
                  '${_attendancePercentage.toStringAsFixed(1)}%',
                ],

                // IMPORTANT:
                // Use Rs. instead of ₹ because default PDF Helvetica
                // does not contain the Indian Rupee Unicode glyph.
                [
                  'Total Fees',
                  'Rs.${_totalFees.toStringAsFixed(2)}',
                ],
                [
                  'Paid Fees',
                  'Rs.${_paidFees.toStringAsFixed(2)}',
                ],
                [
                  'Pending Fees',
                  'Rs.${_pendingFees.toStringAsFixed(2)}',
                ],
              ],
            ),

            pw.SizedBox(height: 25),

            pw.Text(
              'Wing Occupancy',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 10),

            pw.Table.fromTextArray(
              headers: ['Wing', 'Occupied Rooms'],
              data: _wingOccupied.entries
                  .map(
                    (entry) => [
                      entry.key,
                      entry.value.toString(),
                    ],
                  )
                  .toList(),
            ),

            pw.SizedBox(height: 25),

            pw.Text(
              'Report generated by Hostel Management System',
              style: const pw.TextStyle(
                fontSize: 9,
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await document.save();

    _download(
      bytes,
      'hostel_report.pdf',
      'application/pdf',
    );
  }

  // ============================================================
  // DOWNLOAD
  // ============================================================

  void _download(
    List<int> bytes,
    String filename,
    String mimeType,
  ) {
    final blob = html.Blob(
      [Uint8List.fromList(bytes)],
      mimeType,
    );

    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();

    html.Url.revokeObjectUrl(url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$filename exported successfully'),
        ),
      );
    }
  }

  // ============================================================
  // PRINT
  // ============================================================

  Future<void> _printReport() async {
    final document = await _buildPdfDocument();

    await Printing.layoutPdf(
      onLayout: (format) async {
        return document.save();
      },
    );
  }

  Future<pw.Document> _buildPdfDocument() async {
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Text(
              'Hostel Management System',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text('Administrative Report'),
            pw.SizedBox(height: 5),
            pw.Text(
              '${_dateText(_startDate)} - ${_dateText(_endDate)}',
            ),
            pw.SizedBox(height: 20),

            pw.Table.fromTextArray(
              headers: ['Report', 'Value'],
              data: [
                ['Students', '$_totalStudents'],
                ['Rooms', '$_totalRooms'],
                ['Occupied', '$_occupiedRooms'],
                ['Available', '$_availableRooms'],
                [
                  'Occupancy',
                  '${_occupancy.toStringAsFixed(1)}%',
                ],
                ['Check-ins', '$_totalCheckins'],
                ['Check-outs', '$_totalCheckouts'],
                ['Complaints', '$_totalComplaints'],
                ['Open Complaints', '$_openComplaints'],
                ['Visitors', '$_totalVisitors'],
                ['Attendance', '$_totalAttendance'],
                ['Present', '$_presentAttendance'],
                ['Absent', '$_absentAttendance'],

                // Use Rs. for PDF compatibility.
                [
                  'Paid Fees',
                  'Rs.${_paidFees.toStringAsFixed(2)}',
                ],
                [
                  'Pending Fees',
                  'Rs.${_pendingFees.toStringAsFixed(2)}',
                ],
              ],
            ),
          ];
        },
      ),
    );

    return document;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.download),
            onSelected: (value) {
              if (value == 'pdf') {
                _exportPDF();
              } else if (value == 'excel') {
                _exportExcel();
              } else if (value == 'csv') {
                _exportCSV();
              } else if (value == 'print') {
                _printReport();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf),
                  title: Text('Export PDF'),
                ),
              ),
              PopupMenuItem(
                value: 'excel',
                child: ListTile(
                  leading: Icon(Icons.table_chart),
                  title: Text('Export Excel'),
                ),
              ),
              PopupMenuItem(
                value: 'csv',
                child: ListTile(
                  leading: Icon(Icons.description),
                  title: Text('Export CSV'),
                ),
              ),
              PopupMenuItem(
                value: 'print',
                child: ListTile(
                  leading: Icon(Icons.print),
                  title: Text('Print Report'),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadReports,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _error != null
                ? _buildError()
                : _buildDashboard(),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 100),
        const Icon(
          Icons.error_outline,
          size: 65,
        ),
        const SizedBox(height: 15),
        Center(
          child: Text(
            _error!,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeader(),
        const SizedBox(height: 18),
        _buildPeriodFilters(),
        const SizedBox(height: 12),
        _buildLocationFilters(),
        const SizedBox(height: 20),
        _buildAlerts(),
        const SizedBox(height: 22),
        _buildSummary(),
        const SizedBox(height: 25),
        _buildComparison(),
        const SizedBox(height: 25),
        _section(
          'Occupancy Analytics',
          Icons.hotel_outlined,
          _buildOccupancySection(),
        ),
        const SizedBox(height: 25),
        _section(
          'Financial Analytics',
          Icons.account_balance_wallet_outlined,
          _buildFinanceSection(),
        ),
        const SizedBox(height: 25),
        _section(
          'Complaint Analytics',
          Icons.support_agent,
          _buildComplaintSection(),
        ),
        const SizedBox(height: 25),
        _section(
          'Visitor Analytics',
          Icons.people_outline,
          _buildVisitorSection(),
        ),
        const SizedBox(height: 25),
        _section(
          'Attendance Analytics',
          Icons.fact_check_outlined,
          _buildAttendanceSection(),
        ),
        const SizedBox(height: 25),
        _section(
          'Check-in / Check-out Analytics',
          Icons.login_outlined,
          _buildCheckinSection(),
        ),
        const SizedBox(height: 25),
        _section(
          'Wing / Block Occupancy',
          Icons.apartment_outlined,
          _buildWingSection(),
        ),
        const SizedBox(height: 30),
        Center(
          child: Text(
            'Data is generated from your current Firestore collections.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hostel Reports & Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Complete administrative overview of your hostel',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERIOD FILTER
  // ============================================================

  Widget _buildPeriodFilters() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.date_range),
            const SizedBox(width: 5),
            for (final period in [
              'Daily',
              'Weekly',
              'Monthly',
              'Custom',
            ])
              ChoiceChip(
                label: Text(period),
                selected: _period == period,
                onSelected: (_) {
                  if (period == 'Custom') {
                    _pickCustomRange();
                  } else {
                    _setPeriod(period);
                  }
                },
              ),
            const SizedBox(width: 8),
            Text(
              '${_dateText(_startDate)} - ${_dateText(_endDate)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION FILTERS
  // ============================================================

  Widget _buildLocationFilters() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;

            // Responsive dropdown width.
            //
            // Desktop:
            //   220px
            //
            // Smaller screens:
            //   fit available width
            //
            // Three dropdowns can wrap naturally.
            final dropdownWidth = availableWidth < 250
                ? availableWidth
                : 220.0;

            return Wrap(
              spacing: 14,
              runSpacing: 12,
              children: [
                _dropdown(
                  'Hostel',
                  _hostelFilter,
                  _hostels,
                  (value) {
                    setState(() {
                      _hostelFilter = value!;
                    });
                    _calculateReports();
                  },
                  width: dropdownWidth,
                ),
                _dropdown(
                  'Wing / Block',
                  _wingFilter,
                  _wings,
                  (value) {
                    setState(() {
                      _wingFilter = value!;
                    });
                    _calculateReports();
                  },
                  width: dropdownWidth,
                ),
                _dropdown(
                  'Room',
                  _roomFilter,
                  _rooms,
                  (value) {
                    setState(() {
                      _roomFilter = value!;
                    });
                    _calculateReports();
                  },
                  width: dropdownWidth,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // FIXED DROPDOWN
  // ============================================================

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    double width = 220,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        // IMPORTANT:
        // This forces the dropdown's internal Row to use the
        // available width instead of sizing itself naturally.
        isExpanded: true,

        initialValue: items.contains(value) ? value : 'All',

        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
        ),

        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            )
            .toList(),

        onChanged: onChanged,
      ),
    );
  }

  // ============================================================
  // ALERTS
  // ============================================================

  Widget _buildAlerts() {
    final alerts = <Widget>[];

    if (_occupancy > 90) {
      alerts.add(
        _alert(
          Icons.warning_amber,
          'High occupancy',
          'Hostel occupancy has crossed 90%.',
        ),
      );
    }

    if (_pendingFees > 0 &&
        _totalFees > 0 &&
        _pendingFees >= _totalFees * .30) {
      alerts.add(
        _alert(
          Icons.payments_outlined,
          'High pending fees',
          '${_currency(_pendingFees)} remains outstanding.',
        ),
      );
    }

    if (_openComplaints >= 5) {
      alerts.add(
        _alert(
          Icons.report_problem_outlined,
          'Unresolved complaints',
          'There are $_openComplaints open complaints.',
        ),
      );
    }

    if (_todayVisitors >= 20) {
      alerts.add(
        _alert(
          Icons.people_outline,
          'Unusual visitor activity',
          '$_todayVisitors visitors recorded today.',
        ),
      );
    }

    if (alerts.isEmpty) {
      return Card(
        elevation: 1,
        child: ListTile(
          leading: Icon(
            Icons.check_circle,
            color: Colors.green.shade600,
          ),
          title: const Text(
            'No critical alerts',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: const Text(
            'The hostel currently has no major reporting alerts.',
          ),
        ),
      );
    }

    return Column(
      children: alerts,
    );
  }

  Widget _alert(
    IconData icon,
    String title,
    String message,
  ) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(message),
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    final cards = [
      _metric(
        'Students',
        '$_totalStudents',
        Icons.school_outlined,
      ),
      _metric(
        'Occupancy',
        '${_occupancy.toStringAsFixed(1)}%',
        Icons.hotel_outlined,
      ),
      _metric(
        'Pending Fees',
        _currency(_pendingFees),
        Icons.payments_outlined,
      ),
      _metric(
        'Open Complaints',
        '$_openComplaints',
        Icons.support_agent,
      ),
      _metric(
        'Visitors',
        '$_totalVisitors',
        Icons.people_outline,
      ),
      _metric(
        'Attendance',
        '${_attendancePercentage.toStringAsFixed(1)}%',
        Icons.fact_check_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 700
                ? 2
                : 1;

        final width =
            (constraints.maxWidth -
                    ((columns - 1) * 12)) /
                columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _metric(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
      ),
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
                    .withOpacity(.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
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

  // ============================================================
  // COMPARISON
  // ============================================================

  Widget _buildComparison() {
    final difference =
        _thisMonthFees - _lastMonthFees;

    final percentage =
        _lastMonthFees == 0
            ? 0
            : difference /
                  _lastMonthFees *
                  100;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.compare_arrows,
              size: 30,
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'This Month vs Last Month',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Paid fee collection comparison',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  _currency(_thisMonthFees),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${percentage >= 0 ? '+' : ''}${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: percentage >= 0
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION
  // ============================================================

  Widget _section(
    String title,
    IconData icon,
    Widget child,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  // ============================================================
  // OCCUPANCY
  // ============================================================

  Widget _buildOccupancySection() {
    return Column(
      children: [
        _chartCard(
          'Occupancy Trend',
          _occupancyTrend,
          suffix: '%',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: _simpleStat(
                    'Total Rooms',
                    '$_totalRooms',
                  ),
                ),
                Expanded(
                  child: _simpleStat(
                    'Occupied',
                    '$_occupiedRooms',
                  ),
                ),
                Expanded(
                  child: _simpleStat(
                    'Available',
                    '$_availableRooms',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FINANCE
  // ============================================================

  Widget _buildFinanceSection() {
    return Column(
      children: [
        _chartCard(
          'Fee Collection Trend',
          _feeTrend,
          currency: true,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: _simpleStat(
                    'Paid',
                    _currency(_paidFees),
                  ),
                ),
                Expanded(
                  child: _simpleStat(
                    'Pending',
                    _currency(_pendingFees),
                  ),
                ),
                Expanded(
                  child: _simpleStat(
                    'Collection',
                    '${_feeCollectionPercentage.toStringAsFixed(1)}%',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COMPLAINTS
  // ============================================================

  Widget _buildComplaintSection() {
    return Column(
      children: [
        _chartCard(
          'Complaint Trend',
          _complaintTrend,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: _simpleStat(
                    'Total',
                    '$_totalComplaints',
                  ),
                ),
                Expanded(
                  child: _simpleStat(
                    'Open',
                    '$_openComplaints',
                  ),
                ),
                Expanded(
                  child: _simpleStat(
                    'Resolved',
                    '$_resolvedComplaints',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VISITORS
  // ============================================================

  Widget _buildVisitorSection() {
    return Column(
      children: [
        _chartCard(
          'Visitor Trend',
          _visitorTrend,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: _simpleStat(
                    'Total',
                    '$_totalVisitors',
                  ),
                ),
                Expanded(
                  child: _simpleStat(
                    'Today',
                    '$_todayVisitors',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================

  Widget _buildAttendanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _simpleStat(
                    'Attendance',
                    '${_attendancePercentage.toStringAsFixed(1)}%',
                  ),
                ),
                Expanded(
                  child: _simpleStat(
                    'Present',
                    '$_presentAttendance',
                  ),
                ),
                Expanded(
                  child: _simpleStat(
                    'Absent',
                    '$_absentAttendance',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 13,
                value:
                    (_attendancePercentage / 100)
                        .clamp(0, 1),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _totalAttendance == 0
                  ? 'No attendance records found for this period.'
                  : 'Attendance is calculated from the attendance collection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CHECKINS
  // ============================================================

  Widget _buildCheckinSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _simpleStat(
                'Check-ins',
                '$_totalCheckins',
              ),
            ),
            Expanded(
              child: _simpleStat(
                'Check-outs',
                '$_totalCheckouts',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WING
  // ============================================================

  Widget _buildWingSection() {
    if (_wingOccupied.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Center(
            child: Text(
              'No wing/block occupancy data available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: _wingOccupied.entries.map(
            (entry) {
              final total = _roomsData.where((room) {
                if (!_matchesFilters(room)) {
                  return false;
                }

                final wing = _firstValue(room, [
                  'wing',
                  'wingName',
                  'block',
                  'blockName',
                ]);

                return wing == entry.key;
              }).length;

              final percentage =
                  total == 0
                      ? 0
                      : entry.value /
                            total *
                            100;

              return Padding(
                padding:
                    const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${entry.value}/$total rooms',
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      minHeight: 9,
                      value:
                          (percentage / 100)
                              .clamp(0, 1),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment:
                          Alignment.centerRight,
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ).toList(),
        ),
      ),
    );
  }

  // ============================================================
  // SIMPLE STAT
  // ============================================================

  Widget _simpleStat(
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHART
  // ============================================================

  Widget _chartCard(
    String title,
    List<ChartPoint> points, {
    String suffix = '',
    bool currency = false,
  }) {
    if (points.isEmpty) {
      return Card(
        child: SizedBox(
          height: 220,
          child: Center(
            child: Text(
              'No data available for this period.',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      );
    }

    final values =
        points.map((e) => e.value).toList();

    final maxValue = values.reduce(
      (a, b) => a > b ? a : b,
    );

    final maxY =
        maxValue <= 0
            ? 10.0
            : maxValue * 1.25;

    final step =
        points.length <= 7
            ? 1
            : (points.length / 6).ceil();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          15,
          18,
          20,
          15,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget:
                            (value, meta) {
                          final text =
                              currency
                                  ? _currency(value)
                                  : '${value.toStringAsFixed(0)}$suffix';

                          return Text(
                            text,
                            style:
                                const TextStyle(
                              fontSize: 9,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: step.toDouble(),
                        getTitlesWidget:
                            (value, meta) {
                          final index =
                              value.toInt();

                          if (index < 0 ||
                              index >=
                                  points.length) {
                            return const SizedBox();
                          }

                          final date =
                              points[index].date;

                          return Padding(
                            padding:
                                const EdgeInsets.only(
                              top: 8,
                            ),
                            child: Text(
                              '${date.day}/${date.month}',
                              style:
                                  const TextStyle(
                                fontSize: 9,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      dotData: FlDotData(
                        show:
                            points.length <= 15,
                      ),
                      spots: [
                        for (int i = 0;
                            i < points.length;
                            i++)
                          FlSpot(
                            i.toDouble(),
                            points[i].value,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CHART POINT
// ============================================================

class ChartPoint {
  final DateTime date;
  final double value;

  ChartPoint(
    this.date,
    this.value,
  );
}