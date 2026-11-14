import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  bool _notifications = true;
  bool _complaintAlerts = true;
  bool _visitorAlerts = true;
  bool _feeAlerts = true;
  bool _maintenanceMode = false;
  bool _emailNotifications = false;
  bool _autoLogout = true;

  String _themeMode = 'System default';
  String _language = 'English';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // ============================================================
  // LOAD SETTINGS
  // ============================================================

  Future<void> _loadSettings() async {
    try {
      final results = await Future.wait([
        FirebaseService.loadAppSettings(),
        FirebaseService.loadAdminPreferences(),
      ]);

      final appSettings = results[0];
      final adminPreferences = results[1];

      if (!mounted) return;

      setState(() {
        _notifications =
            appSettings['notifications'] as bool? ?? true;

        _complaintAlerts =
            appSettings['complaintAlerts'] as bool? ?? true;

        _visitorAlerts =
            appSettings['visitorAlerts'] as bool? ?? true;

        _feeAlerts =
            appSettings['feeAlerts'] as bool? ?? true;

        _maintenanceMode =
            appSettings['maintenanceMode'] as bool? ?? false;

        _emailNotifications =
            adminPreferences['emailNotifications'] as bool? ?? false;

        _autoLogout =
            adminPreferences['autoLogout'] as bool? ?? true;

        _themeMode =
            _themeFromStoredValue(
          adminPreferences['themeMode'] as String?,
        );

        _language =
            _languageFromStoredValue(
          adminPreferences['language'] as String?,
        );

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showMessage(
        'Unable to load settings: ${_friendlyError(e)}',
        isError: true,
      );
    }
  }

  // ============================================================
  // SAVE SETTINGS
  // ============================================================

  Future<void> _saveSettings() async {
    setState(() => _saving = true);

    try {
      await FirebaseService.saveAllAdminSettings(
        appSettings: {
          'notifications': _notifications,
          'complaintAlerts': _complaintAlerts,
          'visitorAlerts': _visitorAlerts,
          'feeAlerts': _feeAlerts,
          'maintenanceMode': _maintenanceMode,
        },
        adminPreferences: {
          'emailNotifications': _emailNotifications,
          'autoLogout': _autoLogout,
          'themeMode': _themeMode.toLowerCase(),
          'language': _language.toLowerCase(),
        },
      );

      if (!mounted) return;

      _showMessage('Settings saved successfully');
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Failed to save settings: ${_friendlyError(e)}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ============================================================
  // MAINTENANCE MODE
  // ============================================================

  Future<void> _toggleMaintenanceMode(bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded),
                SizedBox(width: 10),
                Flexible(
                  child: Text('Enable Maintenance Mode?'),
                ),
              ],
            ),
            content: const Text(
              'New check-ins and guest registrations may be paused '
              'while maintenance mode is active.\n\n'
              'Existing users will still be able to access the system.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enable'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;
    }

    setState(() => _maintenanceMode = value);
  }

  // ============================================================
  // RESET
  // ============================================================

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset settings?'),
          content: const Text(
            'All administrator settings will be restored to their '
            'default values. You will need to save the settings '
            'to apply them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _notifications = true;
      _complaintAlerts = true;
      _visitorAlerts = true;
      _feeAlerts = true;
      _maintenanceMode = false;
      _emailNotifications = false;
      _autoLogout = true;
      _themeMode = 'System default';
      _language = 'English';
    });

    _showMessage('Settings reset to defaults. Press Save to apply.');
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool changing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: true,
                      enabled: !changing,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      enabled: !changing,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        prefixIcon: Icon(Icons.lock_reset),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      enabled: !changing,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: Icon(
                          Icons.verified_user_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Use at least 6 characters.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: changing
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: changing
                      ? null
                      : () async {
                          final current =
                              currentPasswordController.text.trim();

                          final newPassword =
                              newPasswordController.text;

                          final confirm =
                              confirmPasswordController.text;

                          if (current.isEmpty) {
                            _showMessage(
                              'Enter your current password.',
                              isError: true,
                            );
                            return;
                          }

                          if (newPassword.length < 6) {
                            _showMessage(
                              'New password must contain at least 6 characters.',
                              isError: true,
                            );
                            return;
                          }

                          if (newPassword != confirm) {
                            _showMessage(
                              'New passwords do not match.',
                              isError: true,
                            );
                            return;
                          }

                          setDialogState(() => changing = true);

                          try {
                            await FirebaseService.changeAdminPassword(
                              currentPassword: current,
                              newPassword: newPassword,
                            );

                            if (!dialogContext.mounted) return;

                            Navigator.pop(dialogContext);

                            _showMessage(
                              'Password changed successfully.',
                            );
                          } on FirebaseAuthException catch (e) {
                            setDialogState(() => changing = false);

                            _showMessage(
                              _authErrorMessage(e),
                              isError: true,
                            );
                          } catch (e) {
                            setDialogState(() => changing = false);

                            _showMessage(
                              'Unable to change password.',
                              isError: true,
                            );
                          }
                        },
                  child: changing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout?'),
          content: const Text(
            'You will be signed out from this administrator session. '
            'You can log in again using your admin credentials.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseService.logoutAdmin();

      if (!mounted) return;

      // Returning to the root allows your existing HomePage/login
      // authentication flow to determine what should be displayed.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showMessage(
        _authErrorMessage(e),
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to logout.',
        isError: true,
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(theme),
              const SizedBox(height: 24),

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildAdminProfile(theme),
                          const SizedBox(height: 16),
                          _buildNotificationSettings(theme),
                          const SizedBox(height: 16),
                          _buildAppearanceSettings(theme),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _buildHostelSettings(theme),
                          const SizedBox(height: 16),
                          _buildSecuritySettings(theme),
                          const SizedBox(height: 16),
                          _buildSystemSettings(theme),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                _buildAdminProfile(theme),
                const SizedBox(height: 16),
                _buildNotificationSettings(theme),
                const SizedBox(height: 16),
                _buildHostelSettings(theme),
                const SizedBox(height: 16),
                _buildAppearanceSettings(theme),
                const SizedBox(height: 16),
                _buildSecuritySettings(theme),
                const SizedBox(height: 16),
                _buildSystemSettings(theme),
              ],

              const SizedBox(height: 16),

              _buildDangerZone(theme),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _saving ? null : _saveSettings,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _saving ? 'Saving...' : 'Save All Settings',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  'Hostel Management System • Admin Panel',
                  style: theme.textTheme.bodySmall,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(ThemeData theme) {
    final user = FirebaseService.currentUser;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.primaryContainer,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primary,
            child: Icon(
              Icons.admin_panel_settings,
              size: 32,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Control Center',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ??
                      'Manage your hostel system, notifications and security.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _buildSectionCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      theme.colorScheme.primaryContainer,
                  child: Icon(
                    icon,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ADMIN PROFILE
  // ============================================================

  Widget _buildAdminProfile(ThemeData theme) {
    final user = FirebaseService.currentUser;

    return _buildSectionCard(
      theme: theme,
      icon: Icons.person_outline,
      title: 'Admin Profile',
      subtitle: 'Administrator account information',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: Text(
            user?.displayName ?? 'Hostel Administrator',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${user?.email ?? 'No email'}\nAdministrator',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  Widget _buildNotificationSettings(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      icon: Icons.notifications_outlined,
      title: 'Notifications',
      subtitle: 'Control admin alerts and notifications',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _notifications,
          title: const Text('Enable notifications'),
          subtitle: const Text(
            'Receive important hostel alerts',
          ),
          onChanged: (value) {
            setState(() => _notifications = value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _complaintAlerts,
          title: const Text('Complaint alerts'),
          subtitle: const Text(
            'Notify when a new complaint is submitted',
          ),
          onChanged: _notifications
              ? (value) {
                  setState(() => _complaintAlerts = value);
                }
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _visitorAlerts,
          title: const Text('Visitor alerts'),
          subtitle: const Text(
            'Notify about visitor requests',
          ),
          onChanged: _notifications
              ? (value) {
                  setState(() => _visitorAlerts = value);
                }
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _feeAlerts,
          title: const Text('Fee alerts'),
          subtitle: const Text(
            'Notify about pending or overdue fees',
          ),
          onChanged: _notifications
              ? (value) {
                  setState(() => _feeAlerts = value);
                }
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _emailNotifications,
          title: const Text('Email notifications'),
          subtitle: const Text(
            'Send important alerts to admin email',
          ),
          onChanged: (value) {
            setState(() => _emailNotifications = value);
          },
        ),
      ],
    );
  }

  // ============================================================
  // HOSTEL
  // ============================================================

  Widget _buildHostelSettings(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      icon: Icons.apartment_outlined,
      title: 'Hostel Configuration',
      subtitle: 'Manage basic hostel information',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.business_outlined),
          title: const Text('Hostel name'),
          subtitle: const Text('RIT Hostel'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.phone_outlined),
          title: const Text('Contact information'),
          subtitle: const Text(
            'Manage hostel contact details',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.meeting_room_outlined),
          title: const Text('Room configuration'),
          subtitle: const Text(
            'Manage rooms, wings and capacity',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _maintenanceMode,
          title: const Text(
            'Maintenance mode',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _maintenanceMode
                ? 'New registrations are currently paused'
                : 'System is operating normally',
          ),
          onChanged: _toggleMaintenanceMode,
        ),
      ],
    );
  }

  // ============================================================
  // APPEARANCE
  // ============================================================

  Widget _buildAppearanceSettings(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      icon: Icons.palette_outlined,
      title: 'Appearance',
      subtitle: 'Customize the admin panel',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.brightness_6_outlined),
          title: const Text('Theme'),
          subtitle: const Text(
            'Choose application appearance',
          ),
          trailing: DropdownButton<String>(
            value: _themeMode,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: 'System default',
                child: Text('System'),
              ),
              DropdownMenuItem(
                value: 'Light',
                child: Text('Light'),
              ),
              DropdownMenuItem(
                value: 'Dark',
                child: Text('Dark'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _themeMode = value);
              }
            },
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.language_outlined),
          title: const Text('Language'),
          subtitle: const Text(
            'Application language',
          ),
          trailing: DropdownButton<String>(
            value: _language,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: 'English',
                child: Text('English'),
              ),
              DropdownMenuItem(
                value: 'Marathi',
                child: Text('मराठी'),
              ),
              DropdownMenuItem(
                value: 'Hindi',
                child: Text('हिन्दी'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _language = value);
              }
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECURITY
  // ============================================================

  Widget _buildSecuritySettings(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      icon: Icons.security_outlined,
      title: 'Security',
      subtitle: 'Protect administrator access',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_reset_outlined),
          title: const Text('Change password'),
          subtitle: const Text(
            'Update your administrator password',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showChangePasswordDialog,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _autoLogout,
          title: const Text(
            'Automatic session logout',
          ),
          subtitle: const Text(
            'Improve security on inactive sessions',
          ),
          onChanged: (value) {
            setState(() => _autoLogout = value);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.devices_outlined),
          title: const Text('Active sessions'),
          subtitle: const Text(
            'Firebase manages the current authentication session',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SYSTEM
  // ============================================================

  Widget _buildSystemSettings(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      icon: Icons.settings_applications_outlined,
      title: 'System',
      subtitle: 'Application and system information',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Backend status'),
          subtitle: const Text('Firebase connected'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.green.withValues(alpha: 0.12),
            ),
            child: const Text(
              'Online',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: const Text('App version'),
          subtitle: const Text(
            'Hostel Management System',
          ),
          trailing: const Text('1.0.0'),
        ),
      ],
    );
  }

  // ============================================================
  // DANGER ZONE
  // ============================================================

  Widget _buildDangerZone(ThemeData theme) {
    return Card(
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.error.withValues(
              alpha: 0.4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 10),
                Text(
                  'Danger Zone',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Actions in this section may affect your administrator session.',
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _resetSettings,
              icon: const Icon(Icons.restore),
              label: const Text('Reset settings'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _showLogoutDialog,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _themeFromStoredValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System default';
    }
  }

  String _languageFromStoredValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'marathi':
        return 'Marathi';
      case 'hindi':
        return 'Hindi';
      default:
        return 'English';
    }
  }

  String _friendlyError(Object error) {
    if (error is FirebaseException) {
      return error.message ?? error.code;
    }

    return error.toString();
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect.';

      case 'weak-password':
        return 'The new password is too weak.';

      case 'requires-recent-login':
        return 'Please log in again before changing your password.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'user-disabled':
        return 'This administrator account has been disabled.';

      default:
        return error.message ??
            'Authentication error: ${error.code}';
    }
  }

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
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
  }
}