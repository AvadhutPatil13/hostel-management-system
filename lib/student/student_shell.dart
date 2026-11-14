import 'package:flutter/material.dart';

import '../home_page.dart';
import '../services/session_service.dart';
import '../widgets/dashboard_card.dart';
import 'pages/student_complaints_page.dart';
import 'pages/student_dashboard_page.dart';
import 'pages/student_fees_page.dart';
import 'pages/student_my_room_page.dart';
import 'pages/student_available_rooms_page.dart';
import 'pages/student_notices_page.dart';
import 'pages/student_profile_page.dart';
import 'pages/student_settings_page.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int? _selectedIndex;

  static const _items = <_StudentPanelItem>[
    _StudentPanelItem(
      title: 'Dashboard',
      subtitle: 'View your hostel activity',
      icon: Icons.dashboard_outlined,
      page: StudentDashboardPage(),
    ),
    _StudentPanelItem(
      title: 'My Room',
      subtitle: 'See your assigned room details',
      icon: Icons.meeting_room_outlined,
      page: StudentMyRoomPage(),
    ),
    _StudentPanelItem(
      title: 'Available Rooms',
      subtitle: 'Browse rooms and photos',
      icon: Icons.hotel_outlined,
      page: StudentAvailableRoomsPage(),
    ),
    _StudentPanelItem(
      title: 'Fees',
      subtitle: 'Check fee status and payments',
      icon: Icons.receipt_long_outlined,
      page: const StudentFeesPage(),
    ),
    _StudentPanelItem(
      title: 'Complaints',
      subtitle: 'Review complaints you submitted',
      icon: Icons.report_outlined,
      page: const StudentComplaintsPage(),
    ),
    _StudentPanelItem(
      title: 'Notices',
      subtitle: 'Read important hostel announcements',
      icon: Icons.campaign_outlined,
      page: const StudentNoticesPage(),
    ),
    _StudentPanelItem(
      title: 'Profile',
      subtitle: 'View your student profile',
      icon: Icons.person_outline,
      page: const StudentProfilePage(),
    ),
    _StudentPanelItem(
      title: 'Settings',
      subtitle: 'Manage your panel preferences',
      icon: Icons.settings_outlined,
      page: const StudentSettingsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final title = _selectedIndex == null ? 'Student Panel' : _items[_selectedIndex!].title;

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

class _StudentPanelItem {
  const _StudentPanelItem({
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
