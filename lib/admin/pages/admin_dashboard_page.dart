import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _counts = const {};

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
      final counts = await ApiService.adminDashboard();

      if (!mounted) return;

      setState(() {
        _counts = counts;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load dashboard data.';
        _loading = false;
      });
    }
  }

  int _number(String key) {
    final value = _counts[key];

    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _decimal(String key) {
    final value = _counts[key];

    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Widget _statCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 27,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
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

  Widget _sectionHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _errorCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.error,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unable to load dashboard',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _error ?? 'Something went wrong.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewCard(BuildContext context) {
    final theme = Theme.of(context);

    final students = _number('students');
    final admins = _number('admins');
    final rooms = _number('rooms');
    final activeCheckins = _number('activeCheckins');

    final totalCapacity = _number('totalCapacity');
    final occupiedBeds = _number('occupiedBeds');
    final availableBeds = _number('availableBeds');
    final occupancyPercentage = _decimal('occupancyPercentage');

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.dashboard_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hostel Overview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Current hostel capacity and occupancy',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),

            _overviewRow(
              context,
              icon: Icons.school_outlined,
              title: 'Registered students',
              value: students.toString(),
            ),

            _overviewRow(
              context,
              icon: Icons.meeting_room_outlined,
              title: 'Total rooms',
              value: rooms.toString(),
            ),

            _overviewRow(
              context,
              icon: Icons.bed_outlined,
              title: 'Total bed capacity',
              value: totalCapacity.toString(),
            ),

            _overviewRow(
              context,
              icon: Icons.hotel_outlined,
              title: 'Occupied beds',
              value: occupiedBeds.toString(),
            ),

            _overviewRow(
              context,
              icon: Icons.event_available_outlined,
              title: 'Available beds',
              value: availableBeds.toString(),
            ),

            _overviewRow(
              context,
              icon: Icons.pie_chart_outline,
              title: 'Occupancy',
              value: '${occupancyPercentage.toStringAsFixed(1)}%',
            ),

            _overviewRow(
              context,
              icon: Icons.login_outlined,
              title: 'Currently checked in',
              value: activeCheckins.toString(),
            ),

            _overviewRow(
              context,
              icon: Icons.admin_panel_settings_outlined,
              title: 'Administrators',
              value: admins.toString(),
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  Widget _complaintCard(BuildContext context) {
    final theme = Theme.of(context);

    final total = _number('totalComplaints');
    final open = _number('openComplaints');
    final inProgress = _number('inProgressComplaints');
    final resolved = _number('resolvedComplaints');
    final closed = _number('closedComplaints');

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.support_agent_outlined,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complaint Overview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Current complaint status',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),

            _complaintRow(
              context,
              icon: Icons.list_alt_outlined,
              title: 'Total complaints',
              value: total,
            ),

            _complaintRow(
              context,
              icon: Icons.warning_amber_rounded,
              title: 'Open',
              value: open,
              valueColor: Colors.orange,
            ),

            _complaintRow(
              context,
              icon: Icons.pending_actions_outlined,
              title: 'In progress',
              value: inProgress,
              valueColor: Colors.blue,
            ),

            _complaintRow(
              context,
              icon: Icons.check_circle_outline,
              title: 'Resolved',
              value: resolved,
              valueColor: Colors.green,
            ),

            _complaintRow(
              context,
              icon: Icons.done_all_outlined,
              title: 'Closed',
              value: closed,
              valueColor: Colors.grey,
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _complaintRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int value,
    Color? valueColor,
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                value.toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  Widget _attentionCard(BuildContext context) {
    final theme = Theme.of(context);

    final openComplaints = _number('openComplaints');
    final inProgressComplaints = _number('inProgressComplaints');
    final availableBeds = _number('availableBeds');

    final hasAttention =
        openComplaints > 0 || inProgressComplaints > 0;

    if (!hasAttention) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Everything looks good',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'There are currently no complaints requiring attention.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Attention required',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (openComplaints > 0)
              _attentionRow(
                context,
                icon: Icons.report_problem_outlined,
                title: 'Open complaints',
                message:
                    '$openComplaints complaint${openComplaints == 1 ? '' : 's'} '
                    'require${openComplaints == 1 ? 's' : ''} attention.',
                color: theme.colorScheme.error,
              ),

            if (inProgressComplaints > 0)
              _attentionRow(
                context,
                icon: Icons.pending_actions_outlined,
                title: 'In-progress complaints',
                message:
                    '$inProgressComplaints complaint${inProgressComplaints == 1 ? '' : 's'} '
                    'currently being handled.',
                color: Colors.orange,
              ),

            if (availableBeds > 0)
              _attentionRow(
                context,
                icon: Icons.event_available_outlined,
                title: 'Available beds',
                message:
                    '$availableBeds bed${availableBeds == 1 ? '' : 's'} '
                    'currently available.',
                color: Colors.green,
                showDivider: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _attentionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 21,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;

    final columns = width >= 1200
        ? 4
        : width >= 800
            ? 2
            : 1;

    final horizontalSpacing = width >= 800 ? 16.0 : 0.0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hostel management overview',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh dashboard',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],

          if (_error != null) ...[
            _errorCard(context),
            const SizedBox(height: 16),
          ],

          if (_error == null) ...[
            _sectionHeader(
              context,
              'Quick Statistics',
              'Current hostel system statistics',
            ),

            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: horizontalSpacing,
              mainAxisSpacing: 12,
              childAspectRatio: width >= 800 ? 2.5 : 3.2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _statCard(
                  context: context,
                  title: 'Students',
                  value: _number('students').toString(),
                  icon: Icons.school_outlined,
                  color: Colors.blue,
                ),
                _statCard(
                  context: context,
                  title: 'Rooms',
                  value: _number('rooms').toString(),
                  icon: Icons.meeting_room_outlined,
                  color: Colors.indigo,
                ),
                _statCard(
                  context: context,
                  title: 'Active Check-ins',
                  value: _number('activeCheckins').toString(),
                  icon: Icons.login_outlined,
                  color: Colors.green,
                ),
                _statCard(
                  context: context,
                  title: 'Open Complaints',
                  value: _number('openComplaints').toString(),
                  icon: Icons.report_problem_outlined,
                  color: Colors.orange,
                ),
                _statCard(
                  context: context,
                  title: 'Administrators',
                  value: _number('admins').toString(),
                  icon: Icons.admin_panel_settings_outlined,
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (width >= 1100)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _overviewCard(context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _complaintCard(context),
                  ),
                ],
              )
            else ...[
              _overviewCard(context),
              const SizedBox(height: 16),
              _complaintCard(context),
            ],

            const SizedBox(height: 16),

            _attentionCard(context),
          ],
        ],
      ),
    );
  }
}