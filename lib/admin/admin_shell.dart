import 'package:flutter/material.dart';

import '../home_page.dart';
import '../services/session_service.dart';
import '../widgets/dashboard_card.dart';
import 'pages/admin_checkinout_page.dart';
import 'pages/admin_activity_page.dart';
import 'pages/admin_complaints_page.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/admin_fees_page.dart';
import 'pages/admin_notices_page.dart';
import 'pages/admin_reports_page.dart';
import 'pages/admin_rooms_page.dart';
import 'pages/admin_settings_page.dart';
import 'pages/admin_students_page.dart';
import 'pages/admin_visitors_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int? _selectedIndex;

  static const _items = <_AdminPanelItem>[
    _AdminPanelItem(
      title: 'Dashboard',
      subtitle: 'View key hostel metrics',
      icon: Icons.dashboard_outlined,
      page: AdminDashboardPage(),
    ),
    _AdminPanelItem(
      title: 'Students',
      subtitle: 'Manage student records',
      icon: Icons.people_outline,
      page: AdminStudentsPage(),
    ),
    _AdminPanelItem(
      title: 'Rooms',
      subtitle: 'View room availability',
      icon: Icons.meeting_room_outlined,
      page: AdminRoomsPage(),
    ),
    _AdminPanelItem(
      title: 'Complaints',
      subtitle: 'Track and resolve issues',
      icon: Icons.report_outlined,
      page: AdminComplaintsPage(),
    ),
    _AdminPanelItem(
      title: 'Check-in/out',
      subtitle: 'Manage student check-ins and check-outs',
      icon: Icons.login_outlined,
      page: AdminCheckInOutPage(),
    ),
    _AdminPanelItem(
      title: 'Fees',
      subtitle: 'Manage hostel payments',
      icon: Icons.receipt_long_outlined,
      page: const AdminFeesPage(),
    ),
    _AdminPanelItem(
      title: 'Visitors',
      subtitle: 'Approve and monitor visitors',
      icon: Icons.person_add_alt_1_outlined,
      page: const AdminVisitorsPage(),
    ),
    _AdminPanelItem(
      title: 'Notices',
      subtitle: 'Publish hostel announcements',
      icon: Icons.campaign_outlined,
      page: const AdminNoticesPage(),
    ),
    _AdminPanelItem(
      title: 'Reports',
      subtitle: 'Review hostel performance data',
      icon: Icons.bar_chart_outlined,
      page: const AdminReportsPage(),
    ),
    _AdminPanelItem(
      title: 'Activity Log',
      subtitle: 'Review changes made in the admin panel',
      icon: Icons.history,
      page: const AdminActivityPage(),
    ),
    _AdminPanelItem(
      title: 'Settings',
      subtitle: 'Adjust panel preferences',
      icon: Icons.settings_outlined,
      page: const AdminSettingsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final title = _selectedIndex == null ? 'Admin Panel' : _items[_selectedIndex!].title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: _selectedIndex == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to menu',
                onPressed: () => setState(() => _selectedIndex = null),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Home',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _selectedIndex == null ? _buildMenuGrid(context) : _items[_selectedIndex!].page,
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 700
                ? 3
                : constraints.maxWidth >= 500
                    ? 2
                    : 1;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.05,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return DashboardCard(
              icon: item.icon,
              title: item.title,
              subtitle: item.subtitle,
              onTap: () => setState(() => _selectedIndex = index),
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    await SessionService.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomePage()),
      (route) => false,
    );
  }
}

class _AdminPanelItem {
  const _AdminPanelItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.page,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
}
