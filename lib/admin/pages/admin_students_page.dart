import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class AdminStudentsPage extends StatefulWidget {
  const AdminStudentsPage({super.key});

  @override
  State<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<AdminStudentsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];

  /// Selected student IDs.
  final Set<String> _selectedStudentIds = <String>{};

  bool _loading = true;
  String? _error;

  String _feeFilter = 'all';
  String _checkInFilter = 'all';
  String _sortBy = 'nameAsc';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_applyFilters);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DATA
  // ===========================================================================

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final students = await ApiService.adminStudentManagementData();

      if (!mounted) return;

      setState(() {
        _students = students;
        _loading = false;

        // Remove selections for students that no longer exist.
        final validIds = students
            .map(_studentId)
            .where((id) => id.isNotEmpty)
            .toSet();

        _selectedStudentIds.removeWhere(
          (id) => !validIds.contains(id),
        );
      });

      _applyFilters();
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Unable to load student management data. Please try again.';
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    var result = _students.where((student) {
      final feeStatus =
          _stringValue(student['feeStatus']).toLowerCase();

      final checkInStatus =
          _stringValue(student['checkInStatus']).toLowerCase();

      if (_feeFilter != 'all' && feeStatus != _feeFilter) {
        return false;
      }

      if (_checkInFilter != 'all' &&
          checkInStatus != _checkInFilter) {
        return false;
      }

      if (query.isEmpty) return true;

      final name = _stringValue(student['name']).toLowerCase();
      final email = _stringValue(student['email']).toLowerCase();
      final phone = _stringValue(student['phone']).toLowerCase();
      final id = _stringValue(student['id']).toLowerCase();
      final room = _roomNumber(student).toLowerCase();
      final block = _block(student).toLowerCase();
      final role = _role(student).toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          id.contains(query) ||
          room.contains(query) ||
          block.contains(query) ||
          role.contains(query);
    }).toList();

    switch (_sortBy) {
      case 'nameDesc':
        result.sort(
          (a, b) => _stringValue(b['name'])
              .toLowerCase()
              .compareTo(
                _stringValue(a['name']).toLowerCase(),
              ),
        );
        break;

      case 'roomAsc':
        result.sort(
          (a, b) => _roomNumber(a)
              .toLowerCase()
              .compareTo(
                _roomNumber(b).toLowerCase(),
              ),
        );
        break;

      case 'blockAsc':
        result.sort(
          (a, b) => _block(a)
              .toLowerCase()
              .compareTo(
                _block(b).toLowerCase(),
              ),
        );
        break;

      case 'complaintsDesc':
        result.sort(
          (a, b) => _complaintCount(b).compareTo(
            _complaintCount(a),
          ),
        );
        break;

      case 'visitorsDesc':
        result.sort(
          (a, b) => _visitorCount(b).compareTo(
            _visitorCount(a),
          ),
        );
        break;

      case 'nameAsc':
      default:
        result.sort(
          (a, b) => _stringValue(a['name'])
              .toLowerCase()
              .compareTo(
                _stringValue(b['name']).toLowerCase(),
              ),
        );
    }

    if (!mounted) return;

    setState(() {
      _filteredStudents = result;
    });
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _stringValue(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(
          _stringValue(value),
        ) ??
        0;
  }

  String _studentId(Map<String, dynamic> student) {
    return _stringValue(
      student['id'] ??
          student['uid'] ??
          student['userId'],
    );
  }

  String _displayName(Map<String, dynamic> student) {
    final name = _stringValue(student['name']);

    return name.isEmpty ? 'Unnamed Student' : name;
  }

  String _displayEmail(Map<String, dynamic> student) {
    final email = _stringValue(student['email']);

    return email.isEmpty ? 'No email available' : email;
  }

  String _displayPhone(Map<String, dynamic> student) {
    final phone = _stringValue(student['phone']);

    return phone.isEmpty ? 'No phone number' : phone;
  }

  String _role(Map<String, dynamic> student) {
    final role = _stringValue(
      student['role'] ??
          student['userRole'] ??
          student['accountType'],
    ).toLowerCase();

    if (role == 'admin' || role == 'administrator') {
      return 'admin';
    }

    return 'student';
  }

  String _roleLabel(Map<String, dynamic> student) {
    return _role(student) == 'admin' ? 'ADMIN' : 'STUDENT';
  }

  String _roomNumber(Map<String, dynamic> student) {
    final direct =
        _stringValue(student['currentRoomNumber']);

    if (direct.isNotEmpty) return direct;

    final room = student['currentRoom'];

    if (room is Map) {
      return _stringValue(room['roomNo']);
    }

    return '';
  }

  String _block(Map<String, dynamic> student) {
    final direct =
        _stringValue(student['currentBlock']);

    if (direct.isNotEmpty) return direct;

    final room = student['currentRoom'];

    if (room is Map) {
      return _stringValue(room['building']);
    }

    return '';
  }

  String _floor(Map<String, dynamic> student) {
    final value = student['currentFloor'];

    return value == null ||
            _stringValue(value).isEmpty
        ? ''
        : _stringValue(value);
  }

  bool _isCheckedIn(Map<String, dynamic> student) {
    return _stringValue(
          student['checkInStatus'],
        ).toLowerCase() ==
        'checked_in';
  }

  String _feeStatus(Map<String, dynamic> student) {
    return _stringValue(
      student['feeStatus'],
    ).toLowerCase();
  }

  int _complaintCount(Map<String, dynamic> student) {
    return _intValue(student['complaintCount']);
  }

  int _visitorCount(Map<String, dynamic> student) {
    return _intValue(student['visitorCount']);
  }

  int _feeTotal(Map<String, dynamic> student) {
    return _intValue(student['feeTotalAmount']);
  }

  int _feePaid(Map<String, dynamic> student) {
    return _intValue(student['feePaidAmount']);
  }

  int _feeRemaining(Map<String, dynamic> student) {
    return _intValue(student['feeRemainingAmount']);
  }

  // ===========================================================================
  // SUMMARY COUNTS
  // ===========================================================================

  int get _studentCount => _students.length;

  int get _checkedInCount =>
      _students.where(_isCheckedIn).length;

  int get _feePendingCount =>
      _students.where((student) {
        final status = _feeStatus(student);

        return status == 'pending' ||
            status == 'overdue';
      }).length;

  int get _totalComplaintCount =>
      _students.fold(
        0,
        (sum, student) =>
            sum + _complaintCount(student),
      );

  int get _totalVisitorCount =>
      _students.fold(
        0,
        (sum, student) =>
            sum + _visitorCount(student),
      );

  // ===========================================================================
  // SELECTION / CHECKBOXES
  // ===========================================================================

  bool _isSelected(Map<String, dynamic> student) {
    final id = _studentId(student);

    return id.isNotEmpty &&
        _selectedStudentIds.contains(id);
  }

  void _toggleStudentSelection(
    Map<String, dynamic> student,
    bool selected,
  ) {
    final id = _studentId(student);

    if (id.isEmpty) return;

    setState(() {
      if (selected) {
        _selectedStudentIds.add(id);
      } else {
        _selectedStudentIds.remove(id);
      }
    });
  }

  bool get _allFilteredSelected {
    if (_filteredStudents.isEmpty) {
      return false;
    }

    final validStudents = _filteredStudents
        .where(
          (student) => _studentId(student).isNotEmpty,
        )
        .toList();

    if (validStudents.isEmpty) {
      return false;
    }

    return validStudents.every(_isSelected);
  }

  bool get _someFilteredSelected {
    if (_filteredStudents.isEmpty) {
      return false;
    }

    final validStudents = _filteredStudents
        .where(
          (student) => _studentId(student).isNotEmpty,
        )
        .toList();

    if (validStudents.isEmpty) {
      return false;
    }

    final selectedCount =
        validStudents.where(_isSelected).length;

    return selectedCount > 0 &&
        selectedCount < validStudents.length;
  }

  void _toggleSelectAllFiltered() {
    final validStudents = _filteredStudents
        .where(
          (student) => _studentId(student).isNotEmpty,
        )
        .toList();

    if (validStudents.isEmpty) return;

    final shouldSelectAll =
        !_allFilteredSelected;

    setState(() {
      for (final student in validStudents) {
        final id = _studentId(student);

        if (shouldSelectAll) {
          _selectedStudentIds.add(id);
        } else {
          _selectedStudentIds.remove(id);
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStudentIds.clear();
    });
  }

  List<Map<String, dynamic>> get _selectedStudents {
    return _filteredStudents
        .where(_isSelected)
        .toList();
  }

  // ===========================================================================
  // OPEN SELECTED STUDENTS ONE BY ONE
  // ===========================================================================

  void _openSelectedStudentsOneByOne() {
    final selected = _selectedStudents;

    if (selected.isEmpty) {
      _showMessage(
        'Please select at least one student first.',
        isError: true,
      );

      return;
    }

    _showStudentDetailsSequential(
      selected,
      0,
    );
  }

  void _showStudentDetailsSequential(
    List<Map<String, dynamic>> students,
    int index,
  ) {
    if (!mounted) return;

    if (index < 0 || index >= students.length) {
      return;
    }

    final student = students[index];

    _showStudentDetails(
      student,
      selectedStudents: students,
      selectedIndex: index,
    );
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;

          return ListView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildSummaryCards(context, isWide),
              const SizedBox(height: 16),
              _buildSearchAndFilters(context),
              const SizedBox(height: 12),
              _buildSelectionBar(context),
              const SizedBox(height: 16),
              if (_loading)
                const LinearProgressIndicator(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _buildErrorCard(),
              ],
              if (!_loading && _error == null)
                _buildResults(context, isWide),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student Management',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Students, rooms, fees, check-ins, complaints and visitors',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: _loading ? null : _showAddStudentDialog,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add Student'),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: title),
        actions,
      ],
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    bool isWide,
  ) {
    final cards = [
      _SummaryData(
        title: 'Students',
        value: _studentCount,
        icon: Icons.school_outlined,
      ),
      _SummaryData(
        title: 'Checked In',
        value: _checkedInCount,
        icon: Icons.login_outlined,
      ),
      _SummaryData(
        title: 'Fee Pending',
        value: _feePendingCount,
        icon: Icons
            .account_balance_wallet_outlined,
      ),
      _SummaryData(
        title: 'Complaints',
        value: _totalComplaintCount,
        icon: Icons
            .report_problem_outlined,
      ),
      _SummaryData(
        title: 'Visitors',
        value: _totalVisitorCount,
        icon: Icons.people_alt_outlined,
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            Expanded(
              child: _summaryCard(
                context,
                cards[i],
              ),
            ),
            if (i != cards.length - 1)
              const SizedBox(width: 10),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards.map((card) {
        return SizedBox(
          width: 250,
          child: _summaryCard(
            context,
            card,
          ),
        );
      }).toList(),
    );
  }

  Widget _summaryCard(
    BuildContext context,
    _SummaryData data,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              child: Icon(data.icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.value.toString(),
                    style: Theme.of(context)
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

  // ===========================================================================
  // SEARCH / FILTERS
  // ===========================================================================

  Widget _buildSearchAndFilters(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search students',
                hintText:
                    'Name, email, phone, ID, room, wing or role',
                prefixIcon:
                    const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon:
                                const Icon(Icons.clear),
                            onPressed:
                                _searchController.clear,
                          ),
                border:
                    const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder:
                  (context, constraints) {
                final stacked =
                    constraints.maxWidth < 650;

                final feeDropdown =
                    DropdownButtonFormField<String>(
                  value: _feeFilter,
                  decoration:
                      const InputDecoration(
                    labelText: 'Fee status',
                    border:
                        OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child:
                          Text('All Fee Status'),
                    ),
                    DropdownMenuItem(
                      value: 'paid',
                      child: Text('Paid'),
                    ),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Pending'),
                    ),
                    DropdownMenuItem(
                      value: 'overdue',
                      child: Text('Overdue'),
                    ),
                    DropdownMenuItem(
                      value: 'no_record',
                      child:
                          Text('No Fee Record'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _feeFilter = value;
                    });

                    _applyFilters();
                  },
                );

                final checkInDropdown =
                    DropdownButtonFormField<String>(
                  value: _checkInFilter,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Check-in status',
                    border:
                        OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'All Check-in Status',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'checked_in',
                      child:
                          Text('Checked In'),
                    ),
                    DropdownMenuItem(
                      value: 'checked_out',
                      child:
                          Text('Checked Out'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _checkInFilter = value;
                    });

                    _applyFilters();
                  },
                );

                final sortDropdown =
                    DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration:
                      const InputDecoration(
                    labelText: 'Sort by',
                    border:
                        OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'nameAsc',
                      child:
                          Text('Name A–Z'),
                    ),
                    DropdownMenuItem(
                      value: 'nameDesc',
                      child:
                          Text('Name Z–A'),
                    ),
                    DropdownMenuItem(
                      value: 'roomAsc',
                      child: Text('Room'),
                    ),
                    DropdownMenuItem(
                      value: 'blockAsc',
                      child:
                          Text('Wing / Block'),
                    ),
                    DropdownMenuItem(
                      value: 'complaintsDesc',
                      child:
                          Text('Most Complaints'),
                    ),
                    DropdownMenuItem(
                      value: 'visitorsDesc',
                      child:
                          Text('Most Visitors'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _sortBy = value;
                    });

                    _applyFilters();
                  },
                );

                if (stacked) {
                  return Column(
                    children: [
                      feeDropdown,
                      const SizedBox(height: 12),
                      checkInDropdown,
                      const SizedBox(height: 12),
                      sortDropdown,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: feeDropdown,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: checkInDropdown,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: sortDropdown,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SELECTION BAR
  // ===========================================================================

  Widget _buildSelectionBar(
    BuildContext context,
  ) {
    final selectedCount =
        _selectedStudentIds.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment:
              WrapCrossAlignment.center,
          children: [
            Checkbox(
              value: _allFilteredSelected
                  ? true
                  : _someFilteredSelected
                      ? null
                      : false,
              tristate: true,
              onChanged: (_) {
                _toggleSelectAllFiltered();
              },
            ),
            const Text(
              'Select All',
              style:
                  TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '$selectedCount selected',
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: selectedCount == 0
                  ? null
                  : _openSelectedStudentsOneByOne,
              icon: const Icon(
                Icons.slideshow_outlined,
              ),
              label:
                  const Text('Open Selected One by One'),
            ),
            if (selectedCount > 0)
              OutlinedButton.icon(
                onPressed: _clearSelection,
                icon: const Icon(Icons.clear),
                label:
                    const Text('Clear Selection'),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // RESULTS
  // ===========================================================================

  Widget _buildResults(
    BuildContext context,
    bool isWide,
  ) {
    if (_filteredStudents.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          '${_filteredStudents.length} student'
          '${_filteredStudents.length == 1 ? '' : 's'} found',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        if (isWide)
          _buildDesktopTable(context)
        else
          _buildMobileList(context),
      ],
    );
  }

  // ===========================================================================
  // DESKTOP TABLE
  // ===========================================================================

  Widget _buildDesktopTable(
  BuildContext context,
) {
  return Card(
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        // IMPORTANT:
        // Disable Flutter's automatic checkbox column.
        // We are creating our own checkbox column below.
        showCheckboxColumn: false,

        columnSpacing: 22,

        columns: [
          // ---------------------------------------------------------------
          // SELECT ALL CHECKBOX
          // ---------------------------------------------------------------
          DataColumn(
            label: Checkbox(
              value: _allFilteredSelected
                  ? true
                  : _someFilteredSelected
                      ? null
                      : false,
              tristate: true,
              onChanged: (_) {
                _toggleSelectAllFiltered();
              },
            ),
          ),

          const DataColumn(
            label: Text('Student'),
          ),

          const DataColumn(
            label: Text('Role'),
          ),

          const DataColumn(
            label: Text('Room / Wing'),
          ),

          const DataColumn(
            label: Text('Fee Status'),
          ),

          const DataColumn(
            label: Text('Check-in'),
          ),

          const DataColumn(
            label: Text('Complaints'),
          ),

          const DataColumn(
            label: Text('Visitors'),
          ),

          const DataColumn(
            label: Text('Actions'),
          ),
        ],

        rows: _filteredStudents.map(
          (student) {
            final selected = _isSelected(student);

            return DataRow(
              // Keep this so clicking the row itself can open details.
              // Because showCheckboxColumn is false, Flutter will NOT
              // create another checkbox.
              onSelectChanged: (_) {
                _showStudentDetails(student);
              },

              cells: [
                // ---------------------------------------------------------
                // INDIVIDUAL STUDENT CHECKBOX
                // ---------------------------------------------------------
                DataCell(
                  Checkbox(
                    value: selected,
                    onChanged: (value) {
                      _toggleStudentSelection(
                        student,
                        value ?? false,
                      );
                    },
                  ),
                ),

                // ---------------------------------------------------------
                // STUDENT
                // ---------------------------------------------------------
                DataCell(
                  _studentIdentity(student),
                ),

                // ---------------------------------------------------------
                // ROLE
                // ---------------------------------------------------------
                DataCell(
                  _roleChip(student),
                ),

                // ---------------------------------------------------------
                // ROOM / WING
                // ---------------------------------------------------------
                DataCell(
                  _roomCell(student),
                ),

                // ---------------------------------------------------------
                // FEE STATUS
                // ---------------------------------------------------------
                DataCell(
                  _feeChip(student),
                ),

                // ---------------------------------------------------------
                // CHECK-IN
                // ---------------------------------------------------------
                DataCell(
                  _checkInChip(student),
                ),

                // ---------------------------------------------------------
                // COMPLAINTS
                // ---------------------------------------------------------
                DataCell(
                  _countCell(
                    Icons.report_problem_outlined,
                    _complaintCount(student),
                  ),
                ),

                // ---------------------------------------------------------
                // VISITORS
                // ---------------------------------------------------------
                DataCell(
                  _countCell(
                    Icons.people_alt_outlined,
                    _visitorCount(student),
                  ),
                ),

                // ---------------------------------------------------------
                // ACTIONS
                // ---------------------------------------------------------
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'View details',
                        icon: const Icon(
                          Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            _showStudentDetails(student),
                      ),

                      IconButton(
                        tooltip: 'Change role',
                        icon: const Icon(
                          Icons.manage_accounts_outlined,
                        ),
                        onPressed: () =>
                            _showChangeRoleDialog(student),
                      ),

                      IconButton(
                        tooltip: 'Edit student',
                        icon: const Icon(
                          Icons.edit_outlined,
                        ),
                        onPressed: () =>
                            _showEditUserDialog(student),
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
  );
}

  // ===========================================================================
  // STUDENT IDENTITY
  // ===========================================================================

  Widget _studentIdentity(
    Map<String, dynamic> student,
  ) {
    final name = _displayName(student);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 19,
          child: Text(
            name[0].toUpperCase(),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 170,
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                name,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _displayEmail(student),
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // ROLE
  // ===========================================================================

  Widget _roleChip(
    Map<String, dynamic> student,
  ) {
    final isAdmin = _role(student) == 'admin';

    return Chip(
      avatar: Icon(
        isAdmin
            ? Icons.admin_panel_settings_outlined
            : Icons.school_outlined,
        size: 17,
      ),
      label: Text(
        isAdmin ? 'ADMIN' : 'STUDENT',
      ),
    );
  }

  // ===========================================================================
  // ROOM
  // ===========================================================================

  Widget _roomCell(
    Map<String, dynamic> student,
  ) {
    final room = _roomNumber(student);
    final block = _block(student);
    final floor = _floor(student);

    if (room.isEmpty) {
      return const Text('Not assigned');
    }

    return Column(
      mainAxisAlignment:
          MainAxisAlignment.center,
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          room,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          [
            if (block.isNotEmpty) block,
            if (floor.isNotEmpty)
              'Floor $floor',
          ].join(' • '),
          style:
              const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _countCell(
    IconData icon,
    int count,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(count.toString()),
      ],
    );
  }

  // ===========================================================================
  // MOBILE
  // ===========================================================================

  Widget _buildMobileList(
    BuildContext context,
  ) {
    return Column(
      children: _filteredStudents.map(
        (student) {
          return _buildStudentCard(
            context,
            student,
          );
        },
      ).toList(),
    );
  }

  Widget _buildStudentCard(
    BuildContext context,
    Map<String, dynamic> student,
  ) {
    final name = _displayName(student);
    final room = _roomNumber(student);
    final block = _block(student);
    final selected =
        _isSelected(student);

    return Card(
      margin:
          const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () =>
            _showStudentDetails(student),
        borderRadius:
            BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: (value) {
                      _toggleStudentSelection(
                        student,
                        value ?? false,
                      );
                    },
                  ),
                  CircleAvatar(
                    radius: 22,
                    child: Text(
                      name[0].toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _displayEmail(student),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'view') {
                        _showStudentDetails(
                          student,
                        );
                      } else if (value == 'role') {
                        _showChangeRoleDialog(
                          student,
                        );
                      } else if (value == 'edit') {
                        _showEditUserDialog(
                          student,
                        );
                      }
                    },
                    itemBuilder:
                        (context) => const [
                      PopupMenuItem(
                        value: 'view',
                        child: Text(
                          'View details',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'role',
                        child: Text(
                          'Change role',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          'Edit student',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Align(
                alignment:
                    Alignment.centerLeft,
                child: _roleChip(student),
              ),

              const Divider(height: 22),

              Row(
                children: [
                  Expanded(
                    child: _mobileInfo(
                      Icons
                          .meeting_room_outlined,
                      'Room',
                      room.isEmpty
                          ? 'Not assigned'
                          : [
                              room,
                              if (block
                                  .isNotEmpty)
                                block,
                            ].join(' • '),
                    ),
                  ),
                  Expanded(
                    child: _mobileInfo(
                      Icons.login_outlined,
                      'Check-in',
                      _isCheckedIn(student)
                          ? 'Checked In'
                          : 'Checked Out',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child:
                        _feeChip(student),
                  ),
                  const SizedBox(width: 8),
                  _smallCount(
                    Icons
                        .report_problem_outlined,
                    _complaintCount(student),
                  ),
                  const SizedBox(width: 8),
                  _smallCount(
                    Icons.people_alt_outlined,
                    _visitorCount(student),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileInfo(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    const TextStyle(
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallCount(
    IconData icon,
    int count,
  ) {
    return Chip(
      avatar: Icon(
        icon,
        size: 16,
      ),
      label: Text(
        count.toString(),
      ),
      visualDensity:
          VisualDensity.compact,
    );
  }

  // ===========================================================================
  // FEE
  // ===========================================================================

  Widget _feeChip(
    Map<String, dynamic> student,
  ) {
    final status =
        _feeStatus(student);

    switch (status) {
      case 'paid':
        return const Chip(
          avatar: Icon(
            Icons.check_circle_outline,
            size: 17,
          ),
          label: Text('PAID'),
        );

      case 'overdue':
        return const Chip(
          avatar: Icon(
            Icons.warning_amber_outlined,
            size: 17,
          ),
          label: Text('OVERDUE'),
        );

      case 'pending':
        return const Chip(
          avatar: Icon(
            Icons.pending_outlined,
            size: 17,
          ),
          label: Text('PENDING'),
        );

      default:
        return const Chip(
          avatar: Icon(
            Icons.remove_circle_outline,
            size: 17,
          ),
          label: Text('NO RECORD'),
        );
    }
  }

  Widget _checkInChip(
    Map<String, dynamic> student,
  ) {
    return _isCheckedIn(student)
        ? const Chip(
            avatar: Icon(
              Icons.login_outlined,
              size: 17,
            ),
            label:
                Text('CHECKED IN'),
          )
        : const Chip(
            avatar: Icon(
              Icons.logout_outlined,
              size: 17,
            ),
            label:
                Text('CHECKED OUT'),
          );
  }

  // ===========================================================================
  // EMPTY / ERROR
  // ===========================================================================

  Widget _buildEmptyState() {
    final hasSearch =
        _searchController.text
            .trim()
            .isNotEmpty;

    final hasFilter =
        _feeFilter != 'all' ||
            _checkInFilter != 'all';

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(
              Icons.school_outlined,
              size: 52,
            ),
            const SizedBox(height: 12),
            Text(
              hasSearch || hasFilter
                  ? 'No students match the selected search or filters.'
                  : 'No students found.',
              textAlign:
                  TextAlign.center,
            ),
            if (hasSearch || hasFilter) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _clearFilters,
                child:
                    const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              _error ??
                  'Something went wrong.',
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  _loading ? null : _load,
              icon: const Icon(
                Icons.refresh,
              ),
              label:
                  const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _feeFilter = 'all';
      _checkInFilter = 'all';
      _sortBy = 'nameAsc';
    });

    _applyFilters();
  }

  // ===========================================================================
  // STUDENT DETAILS
  // ===========================================================================

  void _showStudentDetails(
    Map<String, dynamic> student, {
    List<Map<String, dynamic>>? selectedStudents,
    int? selectedIndex,
  }) {
    final room = student['currentRoom'] is Map
        ? Map<String, dynamic>.from(
            student['currentRoom'] as Map,
          )
        : null;

    final activeCheckin =
        student['activeCheckin'] is Map
            ? Map<String, dynamic>.from(
                student['activeCheckin'] as Map,
              )
            : null;

    final hasNavigation =
        selectedStudents != null &&
            selectedIndex != null;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                child: Text(
                  _displayName(student)[0]
                      .toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _displayName(student),
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    'Student Information',
                  ),

                  _detailRow(
                    Icons.email_outlined,
                    'Email',
                    _displayEmail(student),
                  ),

                  _detailRow(
                    Icons.phone_outlined,
                    'Phone',
                    _displayPhone(student),
                  ),

                  _detailRow(
                    Icons
                        .admin_panel_settings_outlined,
                    'Role',
                    _roleLabel(student),
                  ),

                  _detailRow(
                    Icons.wc_outlined,
                    'Gender',
                    _stringValue(
                              student['gender'],
                            )
                            .isEmpty
                        ? 'Not provided'
                        : _stringValue(
                            student['gender'],
                          ),
                  ),

                  _detailRow(
                    Icons.cake_outlined,
                    'Age',
                    _stringValue(
                              student['age'],
                            )
                            .isEmpty
                        ? 'Not provided'
                        : _stringValue(
                            student['age'],
                          ),
                  ),

                  const SizedBox(height: 12),
                  _sectionTitle('Address & Parent / Guardian'),
                  _detailRow(
                    Icons.home_outlined,
                    'Address',
                    _stringValue(student['address']).isEmpty
                        ? 'Not provided'
                        : _stringValue(student['address']),
                  ),
                  _detailRow(
                    Icons.family_restroom_outlined,
                    'Parent / Guardian',
                    _stringValue(student['parentName']).isEmpty
                        ? 'Not provided'
                        : _stringValue(student['parentName']),
                  ),
                  _detailRow(
                    Icons.phone_outlined,
                    'Parent phone',
                    _stringValue(student['parentPhone']).isEmpty
                        ? 'Not provided'
                        : _stringValue(student['parentPhone']),
                  ),
                  _detailRow(
                    Icons.work_outline,
                    'Occupation',
                    _stringValue(student['parentOccupation']).isEmpty
                        ? 'Not provided'
                        : _stringValue(student['parentOccupation']),
                  ),

                  _detailRow(
                    Icons.fingerprint,
                    'Student ID',
                    _studentId(student)
                            .isEmpty
                        ? 'Not available'
                        : _studentId(student),
                  ),

                  const SizedBox(height: 12),

                  _sectionTitle(
                    'Current Room',
                  ),

                  _detailRow(
                    Icons
                        .meeting_room_outlined,
                    'Room',
                    room == null
                        ? 'Not assigned'
                        : _stringValue(
                                    room[
                                        'roomNo'],
                                  )
                                  .isEmpty
                            ? 'Not available'
                            : _stringValue(
                                room['roomNo'],
                              ),
                  ),

                  _detailRow(
                    Icons.domain_outlined,
                    'Wing / Block',
                    room == null
                        ? 'Not assigned'
                        : _stringValue(
                                    room[
                                        'building'],
                                  )
                                  .isEmpty
                            ? 'Not available'
                            : _stringValue(
                                room['building'],
                              ),
                  ),

                  _detailRow(
                    Icons.layers_outlined,
                    'Floor',
                    room == null
                        ? 'Not assigned'
                        : _stringValue(
                                    room[
                                        'floor'],
                                  )
                                  .isEmpty
                            ? 'Not provided'
                            : _stringValue(
                                room['floor'],
                              ),
                  ),

                  _detailRow(
                    Icons.bed_outlined,
                    'Room Type',
                    room == null
                        ? 'Not assigned'
                        : _stringValue(
                                    room['type'],
                                  )
                                  .isEmpty
                            ? 'Not provided'
                            : _stringValue(
                                room['type'],
                              ),
                  ),

                  const SizedBox(height: 12),

                  _sectionTitle(
                    'Check-in Status',
                  ),

                  _detailRow(
                    _isCheckedIn(student)
                        ? Icons.login_outlined
                        : Icons.logout_outlined,
                    'Status',
                    _isCheckedIn(student)
                        ? 'CHECKED IN'
                        : 'CHECKED OUT',
                  ),

                  if (activeCheckin != null)
                    _detailRow(
                      Icons
                          .schedule_outlined,
                      'Check-in Time',
                      _formatDate(
                        activeCheckin[
                            'checkInAt'],
                      ),
                    ),

                  const SizedBox(height: 12),

                  _sectionTitle(
                    'Fee Status',
                  ),

                  _detailRow(
                    Icons
                        .account_balance_wallet_outlined,
                    'Status',
                    _feeStatusLabel(
                      _feeStatus(student),
                    ),
                  ),

                  _detailRow(
                    Icons
                        .receipt_long_outlined,
                    'Fee Records',
                    _intValue(
                      student[
                          'feeRecordCount'],
                    ).toString(),
                  ),

                  _detailRow(
                    Icons.currency_rupee,
                    'Total Fees',
                    '₹${_feeTotal(student)}',
                  ),

                  _detailRow(
                    Icons.payments_outlined,
                    'Paid',
                    '₹${_feePaid(student)}',
                  ),

                  _detailRow(
                    Icons
                        .pending_actions_outlined,
                    'Remaining',
                    '₹${_feeRemaining(student)}',
                  ),

                  const SizedBox(height: 12),

                  _sectionTitle(
                    'Activity',
                  ),

                  _detailRow(
                    Icons
                        .report_problem_outlined,
                    'Complaints',
                    _complaintCount(
                      student,
                    ).toString(),
                  ),

                  _detailRow(
                    Icons.people_alt_outlined,
                    'Visitors',
                    _visitorCount(
                      student,
                    ).toString(),
                  ),
                ],
              ),
            ),
          ),

          actions: [
            if (hasNavigation)
              OutlinedButton.icon(
                onPressed:
                    selectedIndex! > 0
                        ? () {
                            Navigator.of(
                              dialogContext,
                            ).pop();

                            _showStudentDetailsSequential(
                              selectedStudents!,
                              selectedIndex - 1,
                            );
                          }
                        : null,
                icon: const Icon(
                  Icons.arrow_back,
                ),
                label:
                    const Text('Previous'),
              ),

            if (hasNavigation)
              Text(
                '${selectedIndex! + 1} / ${selectedStudents!.length}',
              ),

            if (hasNavigation)
              OutlinedButton.icon(
                onPressed:
                    selectedIndex <
                            selectedStudents
                                .length -
                                1
                        ? () {
                            Navigator.of(
                              dialogContext,
                            ).pop();

                            _showStudentDetailsSequential(
                              selectedStudents,
                              selectedIndex + 1,
                            );
                          }
                        : null,
                icon: const Icon(
                  Icons.arrow_forward,
                ),
                label: const Text('Next'),
              ),

            TextButton(
              onPressed: () =>
                  Navigator.of(
                    dialogContext,
                  ).pop(),
              child:
                  const Text('Close'),
            ),

            FilledButton.icon(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();

                _showChangeRoleDialog(
                  student,
                );
              },
              icon: const Icon(
                Icons
                    .manage_accounts_outlined,
              ),
              label:
                  const Text('Change Role'),
            ),

            FilledButton.icon(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();

                _showEditUserDialog(
                  student,
                );
              },
              icon: const Icon(
                Icons.edit_outlined,
              ),
              label: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(
    String title,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
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
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _feeStatusLabel(
    String status,
  ) {
    switch (status) {
      case 'paid':
        return 'PAID';
      case 'pending':
        return 'PENDING';
      case 'overdue':
        return 'OVERDUE';
      default:
        return 'NO FEE RECORD';
    }
  }

  String _formatDate(
    dynamic value,
  ) {
    if (value == null) {
      return 'Not available';
    }

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else {
      date = DateTime.tryParse(
        _stringValue(value),
      );
    }

    if (date == null) {
      return _stringValue(value);
    }

    final local = date.toLocal();

    String two(int number) =>
        number.toString().padLeft(2, '0');

    return '${local.day}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  // ===========================================================================
  // CHANGE ROLE
  // ===========================================================================

  Future<void> _showChangeRoleDialog(
    Map<String, dynamic> student,
  ) async {
    final studentId =
        _studentId(student);

    if (studentId.isEmpty) {
      _showMessage(
        'Student ID is missing.',
        isError: true,
      );
      return;
    }

    String selectedRole =
        _role(student);

    final result =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Change User Role',
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(student),
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      _displayEmail(student),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    const Text(
                      'Select account role:',
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    RadioListTile<String>(
                      value: 'student',
                      groupValue:
                          selectedRole,
                      title: const Text(
                        'Student',
                      ),
                      subtitle:
                          const Text(
                        'Normal hostel student account',
                      ),
                      secondary: const Icon(
                        Icons
                            .school_outlined,
                      ),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedRole =
                              value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      value: 'admin',
                      groupValue:
                          selectedRole,
                      title: const Text(
                        'Admin',
                      ),
                      subtitle:
                          const Text(
                        'Administrator account',
                      ),
                      secondary: const Icon(
                        Icons
                            .admin_panel_settings_outlined,
                      ),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedRole =
                              value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(
                        dialogContext,
                      ).pop(),
                  child: const Text(
                    'Cancel',
                  ),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(
                        dialogContext,
                      ).pop(
                        selectedRole,
                      ),
                  child:
                      const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null ||
        result == _role(student)) {
      return;
    }

    await _changeRole(
      student,
      result,
    );
  }

  Future<void> _changeRole(
    Map<String, dynamic> student,
    String newRole,
  ) async {
    final studentId =
        _studentId(student);

    if (studentId.isEmpty) {
      _showMessage(
        'Student ID is missing.',
        isError: true,
      );
      return;
    }

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      await ApiService.adminUpdateUser(studentId, role: newRole);

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      _showMessage(
        '${_displayName(student)} role changed to '
        '${newRole.toUpperCase()}.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Unable to change user role. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _showAddStudentDialog() async {
    final controllers = <String, TextEditingController>{
      'name': TextEditingController(),
      'email': TextEditingController(),
      'password': TextEditingController(),
      'gender': TextEditingController(),
      'age': TextEditingController(),
      'phone': TextEditingController(),
      'address': TextEditingController(),
      'parentName': TextEditingController(),
      'parentPhone': TextEditingController(),
      'parentOccupation': TextEditingController(),
    };
    final formKey = GlobalKey<FormState>();

    try {
      final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add Student'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _studentInput(controllers, 'name', 'Full name'),
                    _studentInput(
                      controllers,
                      'email',
                      'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _studentInput(
                      controllers,
                      'password',
                      'Initial password (minimum 6 characters)',
                      obscureText: true,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _studentInput(
                            controllers,
                            'gender',
                            'Gender',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _studentInput(
                            controllers,
                            'age',
                            'Age',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    _studentInput(
                      controllers,
                      'phone',
                      'Student phone',
                      keyboardType: TextInputType.phone,
                    ),
                    _studentInput(
                      controllers,
                      'address',
                      'Address',
                      maxLines: 3,
                    ),
                    const Divider(height: 28),
                    _studentInput(controllers, 'parentName', 'Parent / guardian name'),
                    _studentInput(
                      controllers,
                      'parentPhone',
                      'Parent / guardian phone',
                      keyboardType: TextInputType.phone,
                    ),
                    _studentInput(
                      controllers,
                      'parentOccupation',
                      'Parent / guardian occupation',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A pending hostel fee of ₹5000 will be created automatically.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop({
                  for (final entry in controllers.entries)
                    entry.key: entry.value.text.trim(),
                });
              },
              child: const Text('Create student'),
            ),
          ],
        ),
      );

      if (values == null || !mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });
      await ApiService.adminCreateStudent(
        name: values['name']!,
        email: values['email']!,
        password: values['password']!,
        gender: values['gender']!,
        age: values['age']!,
        phone: values['phone']!,
        address: values['address']!,
        parentName: values['parentName']!,
        parentPhone: values['parentPhone']!,
        parentOccupation: values['parentOccupation']!,
      );
      if (!mounted) return;
      await _load();
      if (mounted) _showMessage('Student added with an initial ₹5000 fee.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to add student: $e', isError: true);
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Widget _studentInput(
    Map<String, TextEditingController> controllers,
    String field,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controllers[field],
        keyboardType: keyboardType,
        maxLines: maxLines,
        obscureText: obscureText,
        textCapitalization: field == 'email' || field == 'password'
            ? TextCapitalization.none
            : TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return 'Enter $label';
          if (text.isEmpty) return null;
          if (field == 'email' && !text.contains('@')) {
            return 'Enter a valid email';
          }
          if (field == 'password' && text.length < 6) {
            return 'Use at least 6 characters';
          }
          return null;
        },
      ),
    );
  }

  // ===========================================================================
  // EDIT USER
  // ===========================================================================

  Future<void> _showEditUserDialog(
    Map<String, dynamic> student,
  ) async {
    final fields = <String, String>{
      'name': 'Name',
      'phone': 'Student phone',
      'gender': 'Gender',
      'age': 'Age',
      'address': 'Address',
      'parentName': 'Parent / guardian name',
      'parentPhone': 'Parent / guardian phone',
      'parentOccupation': 'Parent / guardian occupation',
    };
    final controllers = <String, TextEditingController>{
      for (final field in fields.keys)
        field: TextEditingController(
          text: _stringValue(student[field]),
        ),
    };
    final formKey = GlobalKey<FormState>();

    try {
      final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit Student Information'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final field in fields.entries)
                      _studentInput(
                        controllers,
                        field.key,
                        field.value,
                        keyboardType: field.key.endsWith('Phone')
                            ? TextInputType.phone
                            : field.key == 'age'
                                ? TextInputType.number
                                : null,
                        maxLines: field.key == 'address' ? 3 : 1,
                        required: field.key == 'name',
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop({
                  for (final entry in controllers.entries)
                    entry.key: entry.value.text.trim(),
                });
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      );

      if (values == null || !mounted) return;
      final studentId = _studentId(student);
      if (studentId.isEmpty) {
        _showMessage('Student ID is missing.', isError: true);
        return;
      }

      setState(() {
        _loading = true;
        _error = null;
      });
      await ApiService.adminUpdateUser(
        studentId,
        name: values['name'],
        phone: values['phone'],
        gender: values['gender'],
        age: values['age'],
        address: values['address'],
        parentName: values['parentName'],
        parentPhone: values['parentPhone'],
        parentOccupation: values['parentOccupation'],
      );
      if (!mounted) return;
      await _load();
      if (mounted) _showMessage('Student information updated.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to update student: $e', isError: true);
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }
}

// ============================================================================
// SUMMARY MODEL
// ============================================================================

class _SummaryData {
  const _SummaryData({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final int value;
  final IconData icon;
}