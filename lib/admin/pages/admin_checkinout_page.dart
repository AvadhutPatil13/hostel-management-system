import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class AdminCheckInOutPage extends StatefulWidget {
  const AdminCheckInOutPage({super.key});

  @override
  State<AdminCheckInOutPage> createState() => _AdminCheckInOutPageState();
}

class _AdminCheckInOutPageState extends State<AdminCheckInOutPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _rooms = const [];
  List<Map<String, dynamic>> _checkins = const [];

  String? _selectedUserId;
  String? _selectedRoomId;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
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
      final results = await Future.wait([
        ApiService.adminListUsers(),
        ApiService.adminListRooms(),
        ApiService.adminListCheckins(),
      ]);

      final users = List<Map<String, dynamic>>.from(
        results[0] as List<Map<String, dynamic>>,
      );

      final rooms = List<Map<String, dynamic>>.from(
        results[1] as List<Map<String, dynamic>>,
      );

      final checkins = List<Map<String, dynamic>>.from(
        results[2] as List<Map<String, dynamic>>,
      );

      if (!mounted) return;

      final active = _activeCheckinsFrom(checkins);

      final activeUserIds = active
    .map((c) {
      final user = c['user'];

      if (user is Map) {
        return (user['id'] ??
                user['uid'] ??
                user['userId'])
            ?.toString();
      }

      return (c['userId'] ??
              c['studentId'])
          ?.toString();
    })
    .whereType<String>()
    .where((id) => id.isNotEmpty)
    .toSet();

      final availableUsers = users.where((user) {
        final role = user['role']?.toString().toLowerCase();

        if (role != null && role.isNotEmpty && role != 'student') {
          return false;
        }

        final id = user['id']?.toString();

        return id != null && !activeUserIds.contains(id);
      }).toList();

      final availableRooms = rooms.where((room) {
        final status = room['status']?.toString().toLowerCase() ?? 'available';

        final occupied = _occupiedCount(room);
        final capacity = _capacity(room);

        return status != 'maintenance' && occupied < capacity;
      }).toList();

      String? selectedUser = _selectedUserId;
      String? selectedRoom = _selectedRoomId;

      if (selectedUser == null ||
          !availableUsers.any(
            (u) => u['id']?.toString() == selectedUser,
          )) {
        selectedUser =
            availableUsers.isNotEmpty
                ? availableUsers.first['id']?.toString()
                : null;
      }

      if (selectedRoom == null ||
          !availableRooms.any(
            (r) => r['id']?.toString() == selectedRoom,
          )) {
        selectedRoom =
            availableRooms.isNotEmpty
                ? availableRooms.first['id']?.toString()
                : null;
      }

      setState(() {
        _users = users;
        _rooms = rooms;
        _checkins = checkins;
        _selectedUserId = selectedUser;
        _selectedRoomId = selectedRoom;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load check-in data: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _activeCheckinsFrom(
    List<Map<String, dynamic>> checkins,
  ) {
    return checkins.where((checkin) {
      final checkOutAt = checkin['checkOutAt']?.toString() ?? '';

      return checkOutAt.trim().isEmpty;
    }).toList();
  }

  List<Map<String, dynamic>> get _activeCheckins {
    return _activeCheckinsFrom(_checkins);
  }

  int _occupiedCount(Map<String, dynamic> room) {
    return int.tryParse(
          room['occupiedCount']?.toString() ?? '',
        ) ??
        0;
  }

  int _capacity(Map<String, dynamic> room) {
    return int.tryParse(
          room['capacity']?.toString() ?? '',
        ) ??
        1;
  }

  List<Map<String, dynamic>> get _availableUsers {
    final activeUserIds = <String>{};

    for (final checkin in _activeCheckins) {
      final user = checkin['user'];

      if (user is Map) {
        final id = user['id']?.toString();

        if (id != null && id.isNotEmpty) {
          activeUserIds.add(id);
        }
      }

      final userId = checkin['userId']?.toString();

      if (userId != null && userId.isNotEmpty) {
        activeUserIds.add(userId);
      }
    }

    return _users.where((user) {
      final role = user['role']?.toString().toLowerCase();

      if (role != null && role.isNotEmpty && role != 'student') {
        return false;
      }

      final id = user['id']?.toString();

      return id != null && !activeUserIds.contains(id);
    }).toList();
  }

  List<Map<String, dynamic>> get _availableRooms {
    return _rooms.where((room) {
      final status = room['status']?.toString().toLowerCase() ?? 'available';

      final occupied = _occupiedCount(room);
      final capacity = _capacity(room);

      return status != 'maintenance' && occupied < capacity;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredActiveCheckins {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _activeCheckins;
    }

    return _activeCheckins.where((checkin) {
      final user = checkin['user'];
      final room = checkin['room'];

      final userMap = user is Map ? user : const {};
      final roomMap = room is Map ? room : const {};

      final userName =
          userMap['name']?.toString().toLowerCase() ?? '';
      final email =
          userMap['email']?.toString().toLowerCase() ?? '';
      final roomNo =
          roomMap['roomNo']?.toString().toLowerCase() ?? '';
      final building =
          roomMap['building']?.toString().toLowerCase() ?? '';

      return userName.contains(query) ||
          email.contains(query) ||
          roomNo.contains(query) ||
          building.contains(query);
    }).toList();
  }

  Future<void> _checkIn() async {
    final userId = _selectedUserId;
    final roomId = _selectedRoomId;

    if (userId == null || roomId == null) {
      _showMessage(
        'Please select a student and an available room.',
        isError: true,
      );
      return;
    }

    final selectedRoom = _rooms.cast<Map<String, dynamic>?>().firstWhere(
          (room) => room?['id']?.toString() == roomId,
          orElse: () => null,
        );

    if (selectedRoom != null) {
      final occupied = _occupiedCount(selectedRoom);
      final capacity = _capacity(selectedRoom);
      final status =
          selectedRoom['status']?.toString().toLowerCase() ?? 'available';

      if (status == 'maintenance') {
        _showMessage(
          'This room is under maintenance.',
          isError: true,
        );
        return;
      }

      if (occupied >= capacity) {
        _showMessage(
          'This room is already full.',
          isError: true,
        );
        await _load();
        return;
      }
    }

    try {
      await ApiService.adminCheckIn(
        userId: userId,
        roomId: roomId,
      );

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      _showMessage('Student checked in successfully.');
    } on ApiException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message,
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Check-in failed: $e',
        isError: true,
      );
    }
  }

  Future<void> _checkOut(String checkinId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Check-out'),
          content: const Text(
            'Are you sure you want to check out this student?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Check out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.adminCheckOut(
        checkinId: checkinId,
      );

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      _showMessage('Student checked out successfully.');
    } on ApiException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message,
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Check-out failed: $e',
        isError: true,
      );
    }
  }

  Future<void> _swapStudents() async {
      final active = _activeCheckins;
      if (active.length < 2) {
        _showMessage(
          'At least two checked-in students are needed to swap rooms.',
          isError: true,
        );
        return;
      }

      String? firstId = active[0]['id']?.toString();
      String? secondId = active[1]['id']?.toString();
      final selected = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            String studentLabel(Map<String, dynamic> checkin) {
              final user = checkin['user'] is Map
                  ? Map<String, dynamic>.from(checkin['user'] as Map)
                  : <String, dynamic>{};
              final room = checkin['room'] is Map
                  ? Map<String, dynamic>.from(checkin['room'] as Map)
                  : <String, dynamic>{};
              final name = user['name']?.toString() ?? 'Student';
              final roomNo = room['roomNo']?.toString() ?? 'Unknown room';
              final building = room['building']?.toString() ?? '';
              return '$name — $building / $roomNo';
            }

            return AlertDialog(
              title: const Text('Swap Students Between Rooms'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: firstId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'First student',
                        border: OutlineInputBorder(),
                      ),
                      items: active
                          .map(
                            (checkin) => DropdownMenuItem(
                              value: checkin['id']?.toString(),
                              child: Text(
                                studentLabel(checkin),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => firstId = value),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: secondId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Second student',
                        border: OutlineInputBorder(),
                      ),
                      items: active
                          .map(
                            (checkin) => DropdownMenuItem(
                              value: checkin['id']?.toString(),
                              child: Text(
                                studentLabel(checkin),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => secondId = value),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Room assignments will be exchanged. Both students remain checked in.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: firstId == null ||
                          secondId == null ||
                          firstId == secondId
                      ? null
                      : () => Navigator.pop(dialogContext, {
                            'first': firstId!,
                            'second': secondId!,
                          }),
                  child: const Text('Swap rooms'),
                ),
              ],
            );
          },
        ),
      );
      if (selected == null || !mounted) return;

      try {
        await ApiService.adminSwapRooms(
          firstCheckinId: selected['first']!,
          secondCheckinId: selected['second']!,
        );
        if (!mounted) return;
        await _load();
        if (mounted) _showMessage('Room assignments swapped successfully.');
      } on ApiException catch (e) {
        if (mounted) _showMessage(e.message, isError: true);
      } catch (e) {
        if (mounted) _showMessage('Room swap failed: $e', isError: true);
      }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  String _userName(Map<String, dynamic> checkin) {
    final user = checkin['user'];

    if (user is Map) {
      final name = user['name']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        return name;
      }

      final email = user['email']?.toString().trim();

      if (email != null && email.isNotEmpty) {
        return email;
      }
    }

    return 'Student';
  }

  String _userEmail(Map<String, dynamic> checkin) {
    final user = checkin['user'];

    if (user is Map) {
      return user['email']?.toString() ?? '';
    }

    return '';
  }

  String _roomName(Map<String, dynamic> checkin) {
    final room = checkin['room'];

    if (room is Map) {
      final building = room['building']?.toString().trim() ?? '';
      final roomNo = room['roomNo']?.toString().trim() ?? '';

      final value = '$building $roomNo'.trim();

      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'Room';
  }

  String _checkInTime(Map<String, dynamic> checkin) {
    final value = checkin['checkInAt']?.toString() ?? '';

    if (value.isEmpty) {
      return '-';
    }

    return value;
  }

  Color _occupancyColor(
    BuildContext context,
    int occupied,
    int capacity,
  ) {
    if (capacity <= 0) {
      return Theme.of(context).colorScheme.primary;
    }

    final ratio = occupied / capacity;

    if (ratio >= 1) {
      return Colors.red;
    }

    if (ratio >= 0.75) {
      return Colors.orange;
    }

    return Colors.green;
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: cardColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
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

  Widget _buildCheckInCard(BuildContext context) {
    final availableUsers = _availableUsers;
    final availableRooms = _availableRooms;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.login,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Check-in',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Assign an available student to an available room',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 700;

                final userField = DropdownButtonFormField<String>(
                  initialValue: availableUsers.any(
                    (user) =>
                        user['id']?.toString() == _selectedUserId,
                  )
                      ? _selectedUserId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Student',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  items: availableUsers.map((user) {
                    final id = user['id']?.toString();

                    final name =
                        user['name']?.toString().trim() ?? '';

                    final email =
                        user['email']?.toString().trim() ?? '';

                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(
                        email.isEmpty
                            ? name
                            : '$name ($email)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _loading || availableUsers.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            _selectedUserId = value;
                          });
                        },
                );

                final roomField = DropdownButtonFormField<String>(
                  initialValue: availableRooms.any(
                    (room) =>
                        room['id']?.toString() == _selectedRoomId,
                  )
                      ? _selectedRoomId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Room',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: availableRooms.map((room) {
                    final id = room['id']?.toString();

                    final building =
                        room['building']?.toString() ?? '';

                    final roomNo =
                        room['roomNo']?.toString() ?? '';

                    final occupied = _occupiedCount(room);
                    final capacity = _capacity(room);

                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(
                        '$building $roomNo '
                        '($occupied/$capacity occupied)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _loading || availableRooms.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            _selectedRoomId = value;
                          });
                        },
                );

                final button = SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed:
                        _loading ||
                                availableUsers.isEmpty ||
                                availableRooms.isEmpty
                            ? null
                            : _checkIn,
                    icon: const Icon(Icons.login),
                    label: const Text('Check in'),
                  ),
                );

                if (compact) {
                  return Column(
                    children: [
                      userField,
                      const SizedBox(height: 12),
                      roomField,
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: button,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: userField),
                    const SizedBox(width: 12),
                    Expanded(child: roomField),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 145,
                      child: button,
                    ),
                  ],
                );
              },
            ),

            if (availableUsers.isEmpty || availableRooms.isEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        availableUsers.isEmpty
                            ? 'No students are currently available for check-in.'
                            : 'No rooms currently have available capacity.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search student, email, building or room...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                    },
                    icon: const Icon(Icons.clear),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    final checkins = _filteredActiveCheckins;

    if (checkins.isEmpty) {
      return _buildEmptyState(
        context,
        filtered: _searchController.text.trim().isNotEmpty,
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: DataTable(
                columnSpacing: 26,
                horizontalMargin: 20,
                headingRowHeight: 54,
                dataRowMinHeight: 72,
                dataRowMaxHeight: 86,
                columns: const [
                  DataColumn(
                    label: Text(
                      'Student',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Room',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Check-in Time',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Action',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: checkins.map((checkin) {
                  final id = checkin['id']?.toString() ?? '';

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              child: Icon(
                                Icons.person_outline,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName(checkin),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_userEmail(checkin).isNotEmpty)
                                  Text(
                                    _userEmail(checkin),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          _roomName(checkin),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(_checkInTime(checkin)),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        OutlinedButton.icon(
                          onPressed: _loading || id.isEmpty
                              ? null
                              : () => _checkOut(id),
                          icon: const Icon(
                            Icons.logout,
                            size: 18,
                          ),
                          label: const Text('Check out'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileCards(BuildContext context) {
    final checkins = _filteredActiveCheckins;

    if (checkins.isEmpty) {
      return _buildEmptyState(
        context,
        filtered: _searchController.text.trim().isNotEmpty,
      );
    }

    return Column(
      children: checkins.map((checkin) {
        final id = checkin['id']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName(checkin),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (_userEmail(checkin).isNotEmpty)
                            Text(
                              _userEmail(checkin),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.meeting_room_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _roomName(checkin),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _checkInTime(checkin),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading || id.isEmpty
                        ? null
                        : () => _checkOut(id),
                    icon: const Icon(Icons.logout),
                    label: const Text('Check out'),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required bool filtered,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                filtered
                    ? Icons.search_off_outlined
                    : Icons.login_outlined,
                size: 54,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 14),
              Text(
                filtered
                    ? 'No matching check-ins'
                    : 'No active check-ins',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                filtered
                    ? 'Try a different search.'
                    : 'There are currently no students checked in.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading && _checkins.isEmpty && _users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null && _checkins.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return desktop
            ? _buildDesktopTable(context)
            : _buildMobileCards(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _activeCheckins.length;

    final totalCapacity = _rooms.fold<int>(
      0,
      (total, room) => total + _capacity(room),
    );

    final totalOccupied = _rooms.fold<int>(
      0,
      (total, room) => total + _occupiedCount(room),
    );

    final availableRoomCount = _availableRooms.length;

    final occupancyColor = _occupancyColor(
      context,
      totalOccupied,
      totalCapacity,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check-in / Check-out',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage student room assignments',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _loading ? null : _load,
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check-in / Check-out',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage student room assignments',
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          if (_loading) const LinearProgressIndicator(),

          if (_error != null && _checkins.isNotEmpty) ...[
            const SizedBox(height: 10),
            MaterialBanner(
              content: Text(_error!),
              leading: const Icon(Icons.warning_amber_outlined),
              actions: [
                TextButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                    });
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],

          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;

              final cards = [
                _buildStatCard(
                  context: context,
                  title: 'Active Check-ins',
                  value: '$activeCount',
                  icon: Icons.login,
                  color: Colors.green,
                ),
                _buildStatCard(
                  context: context,
                  title: 'Available Rooms',
                  value: '$availableRoomCount',
                  icon: Icons.meeting_room_outlined,
                  color: Colors.blue,
                ),
                _buildStatCard(
                  context: context,
                  title: 'Occupied Beds',
                  value: '$totalOccupied',
                  icon: Icons.people_outline,
                  color: occupancyColor,
                ),
                _buildStatCard(
                  context: context,
                  title: 'Total Capacity',
                  value: '$totalCapacity',
                  icon: Icons.hotel_outlined,
                  color: Colors.deepPurple,
                ),
              ];

              if (compact) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    ...cards.map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: card,
                      ),
                    ),
                  ],
                );
              }

              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: cards
                      .map(
                        (card) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: card,
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          _buildCheckInCard(context),

          const SizedBox(height: 18),

          Card(
            child: ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Swap students between rooms'),
              subtitle: const Text(
                'Exchange the current rooms of two checked-in students.',
              ),
              trailing: FilledButton(
                onPressed: _loading || _activeCheckins.length < 2
                    ? null
                    : _swapStudents,
                child: const Text('Swap'),
              ),
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Active Check-ins',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              Text(
                '$activeCount active',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),

          const SizedBox(height: 10),

          _buildSearch(context),

          const SizedBox(height: 12),

          _buildContent(context),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
