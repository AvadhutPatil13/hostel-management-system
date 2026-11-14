import 'package:flutter/material.dart';

import '../../image_preview_page.dart';
import '../../services/api_service.dart';

class StudentMyRoomPage extends StatefulWidget {
  const StudentMyRoomPage({super.key});

  @override
  State<StudentMyRoomPage> createState() => _StudentMyRoomPageState();
}

class _StudentMyRoomPageState extends State<StudentMyRoomPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _roomPayload = const {};
  List<Map<String, dynamic>> _checkins = const [];

  @override
  void initState() {
    super.initState();
    _load();
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
        ApiService.myRoom(),
        ApiService.myCheckins(),
      ]);

      if (!mounted) return;

      setState(() {
        _roomPayload = Map<String, dynamic>.from(
          results[0] as Map,
        );

        _checkins = (results[1] as List)
            .map(
              (item) => Map<String, dynamic>.from(item as Map),
            )
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Something went wrong while loading your room.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const {};
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  String _value(dynamic value, [String fallback = '—']) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? fallback : text;
  }

  String _roomLabel(Map<String, dynamic> room) {
    if (room.isEmpty) return 'Not assigned';

    final building = _value(room['building'], '');
    final roomNo = _value(room['roomNo'], '');

    final parts = [
      if (building.isNotEmpty) building,
      if (roomNo.isNotEmpty) 'Room $roomNo',
    ];

    return parts.isEmpty ? 'Room assigned' : parts.join(' • ');
  }

  List<String> _roomImages(Map<String, dynamic> room) {
    final values = room['roomImages'];
    if (values is! List) return const [];
    return values
        .map((value) => value.toString().trim())
        .where((value) => value.startsWith('http'))
        .toList();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  String _formatDateTime(dynamic value) {
    final date = _parseDate(value);

    if (date == null) {
      return _value(value);
    }

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year • $hour:$minute $period';
  }

  String _formatDate(dynamic value) {
    final date = _parseDate(value);

    if (date == null) {
      return _value(value);
    }

    final local = date.toLocal();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  String _formatTime(dynamic value) {
    final date = _parseDate(value);

    if (date == null) {
      return _value(value);
    }

    final local = date.toLocal();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _duration(
    dynamic checkInValue,
    dynamic checkOutValue,
  ) {
    final checkIn = _parseDate(checkInValue);

    if (checkIn == null) return '';

    final checkOut = checkOutValue == null ||
            checkOutValue.toString().trim().isEmpty
        ? DateTime.now()
        : _parseDate(checkOutValue);

    if (checkOut == null) return '';

    final difference = checkOut.difference(checkIn);

    if (difference.isNegative) return '';

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h';
    }

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }

  Color _statusColor(
    BuildContext context,
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'occupied':
        return Colors.orange;

      case 'available':
        return Colors.green;

      case 'maintenance':
        return Colors.red;

      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'occupied':
        return Icons.people_alt_outlined;

      case 'available':
        return Icons.check_circle_outline;

      case 'maintenance':
        return Icons.build_outlined;

      default:
        return Icons.info_outline;
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Room',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'View your room, roommates and stay information',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    if (_error == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context)
                  .colorScheme
                  .onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onErrorContainer,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Retry',
              onPressed: _load,
              icon: Icon(
                Icons.refresh,
                color: Theme.of(context)
                    .colorScheme
                    .onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnassignedCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.meeting_room_outlined,
                size: 34,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Room Assigned',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have not been assigned a hostel room yet. '
              'Please contact the hostel administrator if you need assistance.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(
    BuildContext context,
    Map<String, dynamic> room,
  ) {
    final building = _value(room['building'], '—');
    final roomNo = _value(room['roomNo'], '—');
    final type = _value(room['type'], '—');
    final floor = _value(room['floor'], '—');
    final capacity = _value(room['capacity']);

    final status = _value(room['status'], 'Unknown');

    final statusColor = _statusColor(
      context,
      status,
    );
    final roomImages = _roomImages(room);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.meeting_room,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$building • Room $roomNo',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Room assignment',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
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
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon(status),
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 600 ? 4 : 2;

                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildRoomInfo(
                      context,
                      Icons.location_city_outlined,
                      'Building',
                      building,
                    ),
                    _buildRoomInfo(
                      context,
                      Icons.door_front_door_outlined,
                      'Room',
                      roomNo,
                    ),
                    _buildRoomInfo(
                      context,
                      Icons.layers_outlined,
                      'Floor',
                      floor,
                    ),
                    _buildRoomInfo(
                      context,
                      Icons.bed_outlined,
                      'Room Type',
                      type,
                    ),
                    _buildRoomInfo(
                      context,
                      Icons.people_outline,
                      'Capacity',
                      capacity,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            Text(
              'Room Photos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            if (roomImages.isEmpty)
              Text(
                'No room photos available.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              SizedBox(
                height: 142,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: roomImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ImagePreviewPage(
                              imageUrls: roomImages,
                              initialIndex: index,
                              title: 'Room Photos',
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1.35,
                          child: Image.network(
                            roomImages[index],
                            fit: BoxFit.cover,
                            cacheWidth: 480,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomInfo(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancyCard(
    BuildContext context,
    int occupancy,
    int capacity,
  ) {
    final safeCapacity = capacity > 0 ? capacity : 1;

    final ratio =
        (occupancy / safeCapacity).clamp(0.0, 1.0);

    final availableBeds =
        capacity > occupancy ? capacity - occupancy : 0;

    final isFull =
        capacity > 0 && occupancy >= capacity;

    final color = isFull
        ? Colors.orange
        : Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      color.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.bed_outlined,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Room Occupancy',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  capacity > 0
                      ? '$occupancy / $capacity'
                      : '$occupancy',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 12,
                backgroundColor:
                    Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isFull
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  size: 18,
                  color: isFull
                      ? Colors.orange
                      : Colors.green,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    isFull
                        ? 'Room is currently full'
                        : '$occupancy students currently assigned',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                ),
                if (!isFull)
                  Text(
                    '$availableBeds ${availableBeds == 1 ? 'bed' : 'beds'} available',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontWeight:
                              FontWeight.w600,
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard(
    BuildContext context,
    Map<String, dynamic> activeCheckin,
  ) {
    final isCheckedIn = activeCheckin.isNotEmpty;

    final checkInAt =
        activeCheckin['checkInAt'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: isCheckedIn
                  ? Colors.green.withValues(alpha: 0.12)
                  : Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
              child: Icon(
                isCheckedIn
                    ? Icons.login_rounded
                    : Icons.logout_rounded,
                color: isCheckedIn
                    ? Colors.green
                    : Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Status',
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
                    isCheckedIn
                        ? 'Currently Checked In'
                        : 'Currently Checked Out',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (isCheckedIn) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Checked in ${_formatDateTime(checkInAt)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            if (isCheckedIn)
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green
                      .withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStayInformation(
    BuildContext context,
    dynamic assignmentDate,
    Map<String, dynamic> activeCheckin,
  ) {
    final checkInAt =
        activeCheckin['checkInAt'];

    final stayDate =
        assignmentDate ?? checkInAt;

    final duration =
        _duration(checkInAt, null);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Current Stay',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 28,
              runSpacing: 16,
              children: [
                _buildStayItem(
                  context,
                  Icons.event_outlined,
                  'Assigned / Started',
                  _formatDate(stayDate),
                ),
                _buildStayItem(
                  context,
                  Icons.login_outlined,
                  'Check-in',
                  _formatTime(checkInAt),
                ),
                if (duration.isNotEmpty)
                  _buildStayItem(
                    context,
                    Icons.schedule_outlined,
                    'Current Stay',
                    duration,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStayItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoommates(
    BuildContext context,
    List<Map<String, dynamic>> roommates,
  ) {
    if (roommates.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.people_outline,
                size: 42,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'No Roommates Found',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'No other students are currently assigned to this room.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Roommates',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  '${roommates.length} ${roommates.length == 1 ? 'student' : 'students'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...roommates.map(
              (roommate) => _buildRoommateTile(
                context,
                roommate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoommateTile(
  BuildContext context,
  Map<String, dynamic> roommate,
) {
  final name = _value(
    roommate['name'],
    'Student',
  );

  final role = _value(
    roommate['role'],
    'student',
  );

  final isCurrentUser =
      roommate['isCurrentUser'] == true;

  final status = _value(
    roommate['status'],
    'Not checked in',
  );

  final isCheckedIn =
      status.toLowerCase() == 'checked in';

  final checkInAt =
      roommate['checkInAt'];

  final statusColor =
      isCheckedIn ? Colors.green : Colors.orange;

  return Container(
    margin: const EdgeInsets.only(
      bottom: 10,
    ),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        // ----------------------------------------------------------
        // Avatar
        // ----------------------------------------------------------
        CircleAvatar(
          radius: 22,
          child: Text(
            name.isNotEmpty
                ? name[0].toUpperCase()
                : 'S',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // ----------------------------------------------------------
        // Name + role + check-in information
        // ----------------------------------------------------------
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                isCurrentUser
                    ? '$name (You)'
                    : name,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 3),

              Text(
                role.toLowerCase() == 'student'
                    ? 'Student'
                    : role,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),

              // Show check-in time only when actually checked in.
              if (isCheckedIn && checkInAt != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Checked in ${_formatTime(checkInAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Colors.green,
                      ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 8),

        // ----------------------------------------------------------
        // Status badge
        // ----------------------------------------------------------
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: statusColor.withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: statusColor,
              ),
              const SizedBox(width: 5),
              Text(
                isCheckedIn
                    ? 'Checked in'
                    : 'Checked out',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildHistoryCard(
    BuildContext context,
    Map<String, dynamic> checkin,
  ) {
    final room = _map(checkin['room']);

    final roomLabel = room.isEmpty
        ? _value(
            checkin['roomId'],
            'Unknown room',
          )
        : _roomLabel(room);

    final checkInAt =
        checkin['checkInAt'];

    final checkOutAt =
        checkin['checkOutAt'];

    final hasCheckout =
        checkOutAt != null &&
        checkOutAt.toString().trim().isNotEmpty;

    final duration =
        _duration(checkInAt, checkOutAt);

    return Card(
      margin:
          const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: hasCheckout
                  ? Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                  : Colors.green
                      .withValues(alpha: 0.12),
              child: Icon(
                hasCheckout
                    ? Icons.history
                    : Icons.login_rounded,
                size: 20,
                color: hasCheckout
                    ? Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                    : Colors.green,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          roomLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                        ),
                      ),
                      if (!hasCheckout)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green
                                .withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatDate(checkInAt),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      _buildTimeItem(
                        context,
                        Icons.login,
                        'In',
                        _formatTime(checkInAt),
                      ),
                      _buildTimeItem(
                        context,
                        Icons.logout,
                        'Out',
                        hasCheckout
                            ? _formatTime(
                                checkOutAt,
                              )
                            : 'Currently active',
                      ),
                      if (duration.isNotEmpty)
                        _buildTimeItem(
                          context,
                          Icons.schedule,
                          'Duration',
                          duration,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildHistory(
    BuildContext context,
  ) {
    if (_checkins.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 42,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'No Check-in History',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your room check-in activity will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _checkins
          .map(
            (checkin) => _buildHistoryCard(
              context,
              checkin,
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _map(
      _roomPayload['room'],
    );

    final activeCheckin = _map(
      _roomPayload['activeCheckin'],
    );

    final roommates = _maps(
      _roomPayload['roommates'],
    );

    final occupancy = (_roomPayload['occupancy'] is num)
        ? (_roomPayload['occupancy'] as num).toInt()
        : int.tryParse(
              _roomPayload['occupancy']?.toString() ?? '',
            ) ??
            0;

    final capacity = (_roomPayload['capacity'] is num)
        ? (_roomPayload['capacity'] as num).toInt()
        : int.tryParse(
              _roomPayload['capacity']?.toString() ?? '',
            ) ??
            int.tryParse(
              room['capacity']?.toString() ?? '',
            ) ??
            0;

    final assignmentDate =
        _roomPayload['assignmentDate'];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(context),

          if (_loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            _buildError(context),
          ],

          const SizedBox(height: 20),

          if (room.isEmpty)
            _buildUnassignedCard(context)
          else ...[
            _buildRoomCard(
              context,
              room,
            ),

            const SizedBox(height: 16),

            _buildOccupancyCard(
              context,
              occupancy,
              capacity,
            ),

            const SizedBox(height: 16),

            _buildStayInformation(
              context,
              assignmentDate,
              activeCheckin,
            ),

            const SizedBox(height: 16),

            _buildCurrentStatusCard(
              context,
              activeCheckin,
            ),

            const SizedBox(height: 24),

            Text(
              'Roommates',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 12),

            _buildRoommates(
              context,
              roommates,
            ),
          ],

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Check-in History',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (_checkins.isNotEmpty)
                Text(
                  '${_checkins.length} ${_checkins.length == 1 ? 'record' : 'records'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          _buildHistory(context),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}