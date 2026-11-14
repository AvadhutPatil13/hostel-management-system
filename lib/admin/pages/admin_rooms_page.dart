import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class AdminRoomsPage extends StatefulWidget {
  const AdminRoomsPage({super.key});

  @override
  State<AdminRoomsPage> createState() => _AdminRoomsPageState();
}

class _AdminRoomsPageState extends State<AdminRoomsPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _rooms = const [];

  final TextEditingController _searchController = TextEditingController();

  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final rooms = await ApiService.adminListRooms();

      if (!mounted) return;

      setState(() {
        _rooms = rooms;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load rooms: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRooms {
    final query = _searchController.text.trim().toLowerCase();

    return _rooms.where((room) {
      final building = room['building']?.toString().toLowerCase() ?? '';
      final roomNo = room['roomNo']?.toString().toLowerCase() ?? '';
      final type = room['type']?.toString().toLowerCase() ?? '';
      final floor = room['floor']?.toString().toLowerCase() ?? '';

      final status =
          room['status']?.toString().toLowerCase() ?? 'available';

      final matchesSearch =
          query.isEmpty ||
          building.contains(query) ||
          roomNo.contains(query) ||
          type.contains(query) ||
          floor.contains(query);

      final matchesStatus =
          _statusFilter == 'All' ||
          status == _statusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  int _occupiedCount(Map<String, dynamic> room) {
    return int.tryParse(room['occupiedCount']?.toString() ?? '') ?? 0;
  }

  int _capacity(Map<String, dynamic> room) {
    return int.tryParse(room['capacity']?.toString() ?? '') ?? 1;
  }

  String _roomStatus(Map<String, dynamic> room) {
  final storedStatus =
      room['status']?.toString().toLowerCase() ?? 'available';

  final occupied = _occupiedCount(room);
  final capacity = _capacity(room);

  // Maintenance always takes priority.
  if (storedStatus == 'maintenance') {
    return 'maintenance';
  }

  // Automatically determine room availability from occupancy.
  if (capacity > 0 && occupied >= capacity) {
    return 'full';
  }

  return 'available';
}

  Color _statusColor(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'full':
        return Colors.red;
      case 'maintenance':
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return 'Available';
      case 'full':
        return 'Full';
      case 'maintenance':
        return 'Maintenance';
      default:
        return status.isEmpty
            ? 'Unknown'
            : status[0].toUpperCase() + status.substring(1);
    }
  }

  Future<void> _openRoomDialog({
    Map<String, dynamic>? room,
  }) async {
    final buildingCtrl = TextEditingController(
      text: room?['building']?.toString() ?? '',
    );

    final roomNoCtrl = TextEditingController(
      text: room?['roomNo']?.toString() ?? '',
    );

    final floorCtrl = TextEditingController(
      text: room?['floor']?.toString() ?? '0',
    );

    final capacityCtrl = TextEditingController(
      text: room?['capacity']?.toString() ?? '1',
    );

    String selectedType =
        room?['type']?.toString().trim().isNotEmpty == true
            ? room!['type'].toString()
            : 'Single';

    const roomTypes = [
      'Single',
      'Double',
      'Triple',
      'Four Sharing',
      'Five Sharing',
    ];

    String selectedStatus =
    room?['status']?.toString().toLowerCase() == 'maintenance'
        ? 'maintenance'
        : 'available';

    const statuses = [
      'available',
      'maintenance',
    ];

    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    room == null
                        ? Icons.add_home_work_outlined
                        : Icons.edit_outlined,
                  ),
                  const SizedBox(width: 10),
                  Text(room == null ? 'Add Room' : 'Edit Room'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: buildingCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Building / Wing',
                            hintText: 'e.g. A Wing',
                            prefixIcon: Icon(Icons.apartment_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter building / wing';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: roomNoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Room Number',
                            hintText: 'e.g. 101',
                            prefixIcon: Icon(Icons.meeting_room_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter room number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          value: roomTypes.contains(selectedType)
                              ? selectedType
                              : roomTypes.first,
                          decoration: const InputDecoration(
                            labelText: 'Room Type',
                            prefixIcon: Icon(Icons.bed_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: roomTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            setDialogState(() {
                              selectedType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: floorCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Floor',
                                  prefixIcon: Icon(Icons.layers_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  final floor =
                                      int.tryParse(value?.trim() ?? '');

                                  if (floor == null || floor < 0) {
                                    return 'Invalid floor';
                                  }

                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: capacityCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Capacity',
                                  prefixIcon:
                                      Icon(Icons.people_outline),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
  final capacity = int.tryParse(value?.trim() ?? '');

  if (capacity == null || capacity <= 0) {
    return 'Invalid capacity';
  }

  if (room != null) {
    final occupied = _occupiedCount(room);

    if (capacity < occupied) {
      return 'Capacity cannot be less than $occupied occupied';
    }
  }

  return null;
},
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          value: statuses.contains(selectedStatus)
                              ? selectedStatus
                              : statuses.first,
                          decoration: const InputDecoration(
                            labelText: 'Room Status',
                            prefixIcon: Icon(Icons.info_outline),
                            border: OutlineInputBorder(),
                          ),
                          items: statuses.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(_statusLabel(status)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            setDialogState(() {
                              selectedStatus = value;
                            });
                          },
                        ),

                        if (room != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people_outline),
                                const SizedBox(width: 10),
                                Text(
                                  'Current occupancy: '
                                  '${_occupiedCount(room)}/${_capacity(room)}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      buildingCtrl.dispose();
      roomNoCtrl.dispose();
      floorCtrl.dispose();
      capacityCtrl.dispose();
      return;
    }

    try {
      final building = buildingCtrl.text.trim();
      final roomNo = roomNoCtrl.text.trim();
      final floor = int.tryParse(floorCtrl.text.trim()) ?? 0;
      final capacity = int.tryParse(capacityCtrl.text.trim()) ?? 1;
      if (room == null) {
        await ApiService.adminCreateRoom(
          building: building,
          roomNo: roomNo,
          type: selectedType,
          floor: floor,
          capacity: capacity,
          status: selectedStatus,
        );
      } else {
        await ApiService.adminUpdateRoom(
          room['id']?.toString() ?? '',
          building: building,
          roomNo: roomNo,
          type: selectedType,
          floor: floor,
          capacity: capacity,
          status: selectedStatus,
        );
      }

      buildingCtrl.dispose();
      roomNoCtrl.dispose();
      floorCtrl.dispose();
      capacityCtrl.dispose();

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            room == null
                ? 'Room added successfully'
                : 'Room updated successfully',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      buildingCtrl.dispose();
      roomNoCtrl.dispose();
      floorCtrl.dispose();
      capacityCtrl.dispose();

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      buildingCtrl.dispose();
      roomNoCtrl.dispose();
      floorCtrl.dispose();
      capacityCtrl.dispose();

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save room: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int get _totalRooms => _rooms.length;

  int get _totalCapacity {
    return _rooms.fold<int>(
      0,
      (total, room) => total + _capacity(room),
    );
  }

  int get _totalOccupied {
    return _rooms.fold<int>(
      0,
      (total, room) => total + _occupiedCount(room),
    );
  }

  int get _availableRooms {
    return _rooms.where(
      (room) => _roomStatus(room) == 'available',
    ).length;
  }

  int get _fullRooms {
    return _rooms.where(
      (room) => _roomStatus(room) == 'full',
    ).length;
  }

  int get _maintenanceRooms {
    return _rooms.where(
      (room) => _roomStatus(room) == 'maintenance',
    ).length;
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

  Widget _buildSearchAndFilters(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;

            if (compact) {
              return Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search building, room, type...',
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
                  const SizedBox(height: 12),
                  _buildStatusFilter(),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search building, room, type...',
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
                const SizedBox(width: 12),
                SizedBox(
                  width: 190,
                  child: _buildStatusFilter(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String>(
      value: _statusFilter,
      decoration: const InputDecoration(
        labelText: 'Status',
        prefixIcon: Icon(Icons.filter_list),
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: 'All',
          child: Text('All Rooms'),
        ),
        DropdownMenuItem(
          value: 'available',
          child: Text('Available'),
        ),
        DropdownMenuItem(
          value: 'full',
          child: Text('Full'),
        ),
        DropdownMenuItem(
          value: 'maintenance',
          child: Text('Maintenance'),
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

  Widget _buildStatusChip(
    BuildContext context,
    String status,
  ) {
    final color = _statusColor(status, context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildOccupancy(
    BuildContext context,
    Map<String, dynamic> room,
  ) {
    final occupied = _occupiedCount(room);
    final capacity = _capacity(room);
    final percentage =
        capacity <= 0 ? 0.0 : (occupied / capacity).clamp(0.0, 1.0);

    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$occupied / $capacity',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: percentage,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    final rooms = _filteredRooms;

    if (rooms.isEmpty) {
      return _buildEmptyState(
        context,
        filtered: true,
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
                columnSpacing: 24,
                horizontalMargin: 20,
                headingRowHeight: 54,
                dataRowMinHeight: 70,
                dataRowMaxHeight: 82,
                columns: const [
                  DataColumn(
                    label: Text(
                      'Room',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Floor',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Occupancy',
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
                rows: rooms.map((room) {
                  final status = _roomStatus(room);

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              child: Icon(
                                Icons.meeting_room_outlined,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${room['building'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Room ${room['roomNo'] ?? ''}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(room['type']?.toString() ?? '-'),
                      ),
                      DataCell(
                        Text('${room['floor'] ?? 0}'),
                      ),
                      DataCell(
                        _buildOccupancy(context, room),
                      ),
                      DataCell(
                        _buildStatusChip(context, status),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: 'Edit room',
                          onPressed: () {
                            _openRoomDialog(room: room);
                          },
                          icon: const Icon(Icons.edit_outlined),
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
    final rooms = _filteredRooms;

    if (rooms.isEmpty) {
      return _buildEmptyState(
        context,
        filtered: true,
      );
    }

    return Column(
      children: rooms.map((room) {
        final status = _roomStatus(room);
        final occupied = _occupiedCount(room);
        final capacity = _capacity(room);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _openRoomDialog(room: room);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        child: const Icon(
                          Icons.meeting_room_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${room['building'] ?? ''} - Room ${room['roomNo'] ?? ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${room['type'] ?? '-'} • Floor ${room['floor'] ?? 0}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      _buildStatusChip(context, status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$occupied / $capacity occupied',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: capacity <= 0
                        ? 0
                        : (occupied / capacity).clamp(0.0, 1.0),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        _openRoomDialog(room: room);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
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
                    : Icons.meeting_room_outlined,
                size: 54,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 14),
              Text(
                filtered
                    ? 'No rooms match your search'
                    : 'No rooms added yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                filtered
                    ? 'Try changing the search or filter.'
                    : 'Add your first room using the button above.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading && _rooms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null && _rooms.isEmpty) {
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchAndFilters(context),
            const SizedBox(height: 16),
            if (desktop)
              _buildDesktopTable(context)
            else
              _buildMobileCards(context),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      'Room Management',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                _loading ? null : () => _openRoomDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Room'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _loading ? null : _load,
                          tooltip: 'Refresh',
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
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
                          'Room Management',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage hostel rooms, capacity and occupancy',
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed:
                        _loading ? null : () => _openRoomDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Room'),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          if (_loading) const LinearProgressIndicator(),

          if (_error != null && _rooms.isNotEmpty) ...[
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
                  title: 'Total Rooms',
                  value: '$_totalRooms',
                  icon: Icons.meeting_room_outlined,
                ),
                _buildStatCard(
                  context: context,
                  title: 'Available',
                  value: '$_availableRooms',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
                _buildStatCard(
                  context: context,
                  title: 'Full',
                  value: '$_fullRooms',
                  icon: Icons.people_outline,
                  color: Colors.red,
                ),
                _buildStatCard(
                  context: context,
                  title: 'Maintenance',
                  value: '$_maintenanceRooms',
                  icon: Icons.build_outlined,
                  color: Colors.orange,
                ),
                _buildStatCard(
                  context: context,
                  title: 'Occupancy',
                  value: '$_totalOccupied / $_totalCapacity',
                  icon: Icons.groups_outlined,
                  color: Colors.blue,
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

          _buildContent(context),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
