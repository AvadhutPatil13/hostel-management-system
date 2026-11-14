import 'package:flutter/material.dart';

import '../../services/session_service.dart';

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await SessionService.getCurrentUser();
    if (!mounted) return;
    setState(() => _profile = user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('My Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(_profile?['name']?.toString() ?? 'Unknown student'),
              subtitle: Text('Name'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email),
              title: Text(_profile?['email']?.toString() ?? 'No email available'),
              subtitle: const Text('Email'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.school),
              title: Text(_profile?['role']?.toString() ?? 'student'),
              subtitle: const Text('Role'),
            ),
          ),
        ],
      ),
    );
  }
}
