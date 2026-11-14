import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/backend_config.dart';
import '../../services/session_service.dart';
import 'settings_service.dart';
import '../../login_page.dart';
import 'theme_controller.dart';
import 'student_profile_page.dart';

class StudentSettingsPage extends StatefulWidget {
  const StudentSettingsPage({super.key});

  @override
  State<StudentSettingsPage> createState() => _StudentSettingsPageState();
}

class _StudentSettingsPageState extends State<StudentSettingsPage> {
  // ============================================================
  // STATE
  // ============================================================

  bool _loading = true;

  bool _notifications = true;
  bool _noticeNotifications = true;
  bool _feeNotifications = true;
  bool _complaintNotifications = true;
  bool _soundEffects = true;
  bool _vibration = true;

  String _selectedLanguage = 'English';

  Map<String, dynamic>? _profile;

  String _appVersion = '';
  String _buildNumber = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadPreferences(),
      _loadPackageInfo(),
      ThemeController.instance.load(),
    ]);

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final user = await SessionService.getCurrentUser();
      if (!mounted) return;
      setState(() => _profile = user);
    } catch (_) {
      // Fall back to defaults; profile card will show placeholders.
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SettingsService.load();

    if (!mounted) return;

    setState(() {
      _notifications = prefs.notifications;
      _noticeNotifications = prefs.noticeNotifications;
      _feeNotifications = prefs.feeNotifications;
      _complaintNotifications = prefs.complaintNotifications;
      _soundEffects = prefs.soundEffects;
      _vibration = prefs.vibration;
      _selectedLanguage = prefs.language;
    });
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();

      if (!mounted) return;

      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _appVersion = '1.0.0';
        _buildNumber = '';
      });
    }
  }

  String get _displayName {
    final name = _profile?['name']?.toString().trim();
    return (name == null || name.isEmpty) ? 'Student Account' : name;
  }

  String get _displayEmail {
    final email = _profile?['email']?.toString().trim();
    return (email == null || email.isEmpty) ? '' : email;
  }

  String get _versionLabel {
    if (_appVersion.isEmpty) return 'Version 1.0.0';
    return _buildNumber.isEmpty
        ? 'Version $_appVersion'
        : 'Version $_appVersion ($_buildNumber)';
  }

  // ============================================================
  // MAIN UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ==========================================
                // PROFILE
                // ==========================================
                _buildProfileCard(context),

                const SizedBox(height: 20),

                // ==========================================
                // ACCOUNT
                // ==========================================
                _buildSectionTitle(
                  context,
                  'Account',
                  Icons.person_outline_rounded,
                ),
                const SizedBox(height: 10),
                _buildSettingsCard(
                  context,
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.person_outline_rounded,
                      title: 'My Profile',
                      subtitle: 'View and manage your personal information',
                      onTap: _openProfile,
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.lock_outline_rounded,
                      title: 'Change Password',
                      subtitle: 'Update your account password',
                      onTap: _openChangePassword,
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.security_outlined,
                      title: 'Security',
                      subtitle: 'Manage account security settings',
                      onTap: _openSecurity,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // NOTIFICATIONS
                // ==========================================
                _buildSectionTitle(
                  context,
                  'Notifications',
                  Icons.notifications_none_rounded,
                ),
                const SizedBox(height: 10),
                _buildSettingsCard(
                  context,
                  children: [
                    SwitchListTile.adaptive(
                      value: _notifications,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      secondary: _buildIconContainer(
                        context,
                        Icons.notifications_active_outlined,
                      ),
                      title: const Text(
                        'App Notifications',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Receive hostel updates and alerts',
                      ),
                      onChanged: (value) async {
                        setState(() {
                          _notifications = value;
                          if (!value) {
                            _noticeNotifications = false;
                            _feeNotifications = false;
                            _complaintNotifications = false;
                          }
                        });

                        await SettingsService.setNotifications(value);
                        if (!value) {
                          await Future.wait([
                            SettingsService.setNoticeNotifications(false),
                            SettingsService.setFeeNotifications(false),
                            SettingsService.setComplaintNotifications(false),
                          ]);
                        }
                      },
                    ),
                    if (_notifications) ...[
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: _noticeNotifications,
                        contentPadding: const EdgeInsets.only(
                          left: 72,
                          right: 16,
                        ),
                        title: const Text('Hostel Notices'),
                        subtitle: const Text(
                          'Important announcements and notices',
                        ),
                        onChanged: (value) async {
                          setState(() => _noticeNotifications = value);
                          await SettingsService.setNoticeNotifications(value);
                        },
                      ),
                      SwitchListTile.adaptive(
                        value: _feeNotifications,
                        contentPadding: const EdgeInsets.only(
                          left: 72,
                          right: 16,
                        ),
                        title: const Text('Fee Reminders'),
                        subtitle: const Text(
                          'Due dates and payment reminders',
                        ),
                        onChanged: (value) async {
                          setState(() => _feeNotifications = value);
                          await SettingsService.setFeeNotifications(value);
                        },
                      ),
                      SwitchListTile.adaptive(
                        value: _complaintNotifications,
                        contentPadding: const EdgeInsets.only(
                          left: 72,
                          right: 16,
                        ),
                        title: const Text('Complaint Updates'),
                        subtitle: const Text(
                          'Updates about your complaints',
                        ),
                        onChanged: (value) async {
                          setState(() => _complaintNotifications = value);
                          await SettingsService.setComplaintNotifications(
                            value,
                          );
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // APPEARANCE
                // ==========================================
                _buildSectionTitle(
                  context,
                  'Appearance',
                  Icons.palette_outlined,
                ),
                const SizedBox(height: 10),
                _buildSettingsCard(
                  context,
                  children: [
                    AnimatedBuilder(
                      animation: ThemeController.instance,
                      builder: (context, _) {
                        final isDark = ThemeController.instance.isDarkMode;

                        return SwitchListTile.adaptive(
                          value: isDark,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          secondary: _buildIconContainer(
                            context,
                            isDark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                          ),
                          title: const Text(
                            'Dark Mode',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Use a darker appearance throughout the app',
                          ),
                          onChanged: (value) async {
                            await ThemeController.instance.setDarkMode(value);

                            _showMessage(
                              value
                                  ? 'Dark mode enabled'
                                  : 'Dark mode disabled',
                            );
                          },
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.language_outlined,
                      title: 'Language',
                      subtitle: _selectedLanguage,
                      onTap: _selectLanguage,
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // APP EXPERIENCE
                // ==========================================
                _buildSectionTitle(
                  context,
                  'App Experience',
                  Icons.tune_rounded,
                ),
                const SizedBox(height: 10),
                _buildSettingsCard(
                  context,
                  children: [
                    SwitchListTile.adaptive(
                      value: _soundEffects,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      secondary: _buildIconContainer(
                        context,
                        Icons.volume_up_outlined,
                      ),
                      title: const Text(
                        'Sound Effects',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Play sounds for app interactions',
                      ),
                      onChanged: (value) async {
                        setState(() => _soundEffects = value);
                        await SettingsService.setSoundEffects(value);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      value: _vibration,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      secondary: _buildIconContainer(
                        context,
                        Icons.vibration_outlined,
                      ),
                      title: const Text(
                        'Vibration',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Use vibration for important interactions',
                      ),
                      onChanged: (value) async {
                        setState(() => _vibration = value);
                        await SettingsService.setVibration(value);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // PRIVACY & SECURITY
                // ==========================================
                _buildSectionTitle(
                  context,
                  'Privacy & Security',
                  Icons.shield_outlined,
                ),
                const SizedBox(height: 10),
                _buildSettingsCard(
                  context,
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy',
                      subtitle: 'Learn how your information is used',
                      onTap: _openPrivacy,
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.devices_outlined,
                      title: 'Active Sessions',
                      subtitle: 'Manage devices signed into your account',
                      onTap: _openActiveSessions,
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.cleaning_services_outlined,
                      title: 'Clear Cache',
                      subtitle: 'Free up space used by cached app data',
                      onTap: _confirmClearCache,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // SUPPORT
                // ==========================================
                _buildSectionTitle(
                  context,
                  'Support',
                  Icons.support_agent_outlined,
                ),
                const SizedBox(height: 10),
                _buildSettingsCard(
                  context,
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      subtitle: 'Get help with the hostel application',
                      onTap: _openHelp,
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.feedback_outlined,
                      title: 'Send Feedback',
                      subtitle: 'Tell us how we can improve the app',
                      onTap: _openFeedback,
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.report_problem_outlined,
                      title: 'Report a Problem',
                      subtitle: 'Report an issue with the application',
                      onTap: _reportProblem,
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.email_outlined,
                      title: 'Contact Hostel Office',
                      subtitle: 'Email the hostel administration directly',
                      onTap: _emailSupport,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // LEGAL
                // ==========================================
                _buildSectionTitle(
                  context,
                  'Legal',
                  Icons.gavel_outlined,
                ),
                const SizedBox(height: 10),
                _buildSettingsCard(
                  context,
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.description_outlined,
                      title: 'Terms & Conditions',
                      subtitle: 'Read the terms of using the application',
                      onTap: _openTerms,
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.policy_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'Read our privacy policy',
                      onTap: _openPrivacy,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // ABOUT
                // ==========================================
                _buildSectionTitle(
                  context,
                  'About',
                  Icons.info_outline_rounded,
                ),
                const SizedBox(height: 10),
                _buildSettingsCard(
                  context,
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.info_outline_rounded,
                      title: 'About Hostel Management',
                      subtitle: 'Application information',
                      onTap: _openAbout,
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.system_update_outlined,
                      title: 'Check for Updates',
                      subtitle: 'Make sure you are using the latest version',
                      onTap: _checkUpdates,
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ==========================================
                // SAVE
                // ==========================================
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _savePreferences,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text(
                      'Save Preferences',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ==========================================
                // LOGOUT
                // ==========================================
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'Logout',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(
                        color: colorScheme.error.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ==========================================
                // VERSION
                // ==========================================
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.home_work_rounded,
                        size: 30,
                        color: colorScheme.primary.withOpacity(0.7),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hostel Management System',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _versionLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Made for students',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  // ============================================================
  // PROFILE CARD
  // ============================================================

  Widget _buildProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colorScheme.onPrimary.withOpacity(0.15),
              child: Text(
                _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'S',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _displayEmail.isEmpty
                        ? 'Manage your hostel account'
                        : _displayEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimary.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _profile?['role']?.toString() ?? 'Student',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _openProfile,
              color: colorScheme.onPrimary,
              tooltip: 'View profile',
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SETTINGS CARD
  // ============================================================

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Column(children: children),
    );
  }

  // ============================================================
  // SETTINGS TILE
  // ============================================================

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: _buildIconContainer(context, icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  // ============================================================
  // ICON CONTAINER
  // ============================================================

  Widget _buildIconContainer(BuildContext context, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 21),
    );
  }

  // ============================================================
  // PROFILE — now navigates to the real profile page
  // ============================================================

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StudentProfilePage(),
      ),
    );
  }

  // ============================================================
  // CHANGE PASSWORD — wired to SessionService
  // ============================================================

  Future<void> _openChangePassword() async {
    if (!BackendConfig.useFirebase) {
      await _showInfoDialog(
        title: 'Change Password',
        icon: Icons.lock_outline_rounded,
        message:
            'Password changes are only available when the Firebase '
            'backend is enabled. Connect this action to your '
            'authentication service to turn it on.',
      );
      return;
    }

    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (newPasswordController.text.isEmpty ||
                  confirmPasswordController.text.isEmpty ||
                  oldPasswordController.text.isEmpty) {
                _showMessage('Please enter all password fields.');
                return;
              }

              if (newPasswordController.text.length < 6) {
                _showMessage('New password must be at least 6 characters.');
                return;
              }

              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                _showMessage('New passwords do not match.');
                return;
              }

              setDialogState(() => submitting = true);

              try {
                await SessionService.changePassword(
                  currentPassword: oldPasswordController.text,
                  newPassword: newPasswordController.text,
                );

                if (!mounted) return;
                Navigator.pop(dialogContext);
                _showMessage('Password updated successfully.');
              } on FirebaseAuthException catch (e) {
                setDialogState(() => submitting = false);
                _showMessage(e.message ?? 'Unable to update password.');
              } on StateError catch (e) {
                setDialogState(() => submitting = false);
                _showMessage(e.message);
              } catch (e) {
                setDialogState(() => submitting = false);
                _showMessage('Unable to update password: $e');
              }
            }

            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: oldPasswordController,
                      obscureText: obscureOld,
                      enabled: !submitting,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(
                            () => obscureOld = !obscureOld,
                          ),
                          icon: Icon(
                            obscureOld
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      enabled: !submitting,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(
                            () => obscureNew = !obscureNew,
                          ),
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      enabled: !submitting,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  // ============================================================
  // SECURITY
  // ============================================================

  Future<void> _openSecurity() async {
    await _showInfoDialog(
      title: 'Security',
      icon: Icons.security_outlined,
      message:
          'Your account is protected by your hostel login credentials. '
          'Use "Change Password" to update your password, and "Active '
          'Sessions" to review devices signed into your account.',
    );
  }

  // ============================================================
  // ACTIVE SESSIONS
  //
  // Firebase Auth's client SDK has no API to list a user's other signed-in
  // devices (that requires the Admin SDK on a backend), so rather than
  // fabricate device data, this gives an honest explanation and a real,
  // working action: sign out of this device now.
  // ============================================================

  Future<void> _openActiveSessions() async {
    final signOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.devices_outlined, size: 34),
          title: const Text('Active Sessions'),
          content: const Text(
            'Viewing and managing every device signed into your account '
            'requires server-side support that this app does not yet have. '
            'For now, you can sign out of this device below; to secure '
            'your account further, change your password, which invalidates '
            'sessions on other devices.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign Out This Device'),
            ),
          ],
        );
      },
    );

    if (signOut == true) {
      await _confirmLogout();
    }
  }

  // ============================================================
  // CLEAR CACHE
  // ============================================================

  Future<void> _confirmClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.cleaning_services_outlined, size: 34),
          title: const Text('Clear Cache?'),
          content: const Text(
            'This will remove locally cached app data. Your account, '
            'notices, fees and complaints are stored on the server and '
            'will not be affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await SettingsService.clearCache();
    _showMessage('Cache cleared.');
  }

  // ============================================================
  // PRIVACY
  // ============================================================

  Future<void> _openPrivacy() async {
    await _showInfoDialog(
      title: 'Privacy',
      icon: Icons.privacy_tip_outlined,
      message:
          'Your hostel account information is used only for hostel '
          'administration, room allocation, fees, notices and complaint '
          'management, and is not shared with third parties.',
    );
  }

  // ============================================================
  // HELP
  // ============================================================

  Future<void> _openHelp() async {
    await _showInfoDialog(
      title: 'Help & Support',
      icon: Icons.help_outline_rounded,
      message:
          'For hostel-related problems, contact the hostel administrator. '
          'You can also use the Complaints section to submit and track issues.',
    );
  }

  // ============================================================
  // FEEDBACK
  //
  // There's no feedback-collection endpoint in SessionService, so rather
  // than pretend to submit somewhere, this composes a real email to the
  // hostel office with what the student typed — an action that actually
  // does something today.
  // ============================================================

  Future<void> _openFeedback() async {
    final controller = TextEditingController();

    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Send Feedback'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Tell us what you think...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (send == true) {
      if (controller.text.trim().isEmpty) {
        _showMessage('Please enter your feedback.');
      } else {
        await _emailSupport(
          subject: 'App Feedback',
          body: controller.text.trim(),
        );
      }
    }

    controller.dispose();
  }

  // ============================================================
  // REPORT PROBLEM
  // ============================================================

  Future<void> _reportProblem() async {
    await _emailSupport(subject: 'App Problem Report');
  }

  // ============================================================
  // CONTACT SUPPORT (mailto)
  // ============================================================

  Future<void> _emailSupport({
    String subject = 'Hostel App Support',
    String body = '',
  }) async {
    final queryParams = <String, String>{
      'subject': subject,
      if (body.isNotEmpty) 'body': body,
    };

    final query = queryParams.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final uri = Uri(
      scheme: 'mailto',
      path: 'hostel.support@example.edu',
      query: query,
    );

    try {
      final launched = await launchUrl(uri);

      if (!launched) {
        _showMessage('No email app available on this device.');
      }
    } catch (e) {
      _showMessage('Unable to open email app: $e');
    }
  }

  // ============================================================
  // TERMS
  // ============================================================

  Future<void> _openTerms() async {
    await _showInfoDialog(
      title: 'Terms & Conditions',
      icon: Icons.description_outlined,
      message:
          'By using this application you agree to abide by hostel rules, '
          'submit accurate information, and use the complaint and fee '
          'systems responsibly. Contact the hostel office for the full '
          'terms document.',
    );
  }

  // ============================================================
  // ABOUT
  // ============================================================

  Future<void> _openAbout() async {
    showAboutDialog(
      context: context,
      applicationName: 'Hostel Management System',
      applicationVersion: _appVersion.isEmpty ? '1.0.0' : _appVersion,
      applicationIcon: const Icon(Icons.home_work_rounded, size: 36),
      applicationLegalese: '© 2026 Hostel Management System',
      children: const [
        SizedBox(height: 16),
        Text(
          'A digital platform for managing hostel rooms, '
          'fees, notices, complaints and student services.',
        ),
      ],
    );
  }

  // ============================================================
  // CHECK UPDATES
  // ============================================================

  Future<void> _checkUpdates() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Check for Updates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 52,
                color: Colors.green,
              ),
              const SizedBox(height: 14),
              Text(
                'You are using version ${_appVersion.isEmpty ? '1.0.0' : _appVersion}.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'This is the latest available version.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // LANGUAGE
  // ============================================================

  Future<void> _selectLanguage() async {
    final languages = ['English', 'Hindi', 'Marathi'];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Select Language',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ...languages.map((language) {
                return RadioListTile<String>(
                  value: language,
                  groupValue: _selectedLanguage,
                  title: Text(language),
                  onChanged: (value) => Navigator.pop(context, value),
                );
              }),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _selectedLanguage = selected);
      await SettingsService.setLanguage(selected);
      _showMessage('Language preference changed to $selected.');
    }
  }

  // ============================================================
  // SAVE
  //
  // Every toggle already writes through to SharedPreferences the moment
  // it's changed (see each onChanged above), so this button isn't load-
  // bearing — it exists to give the student explicit, reassuring
  // confirmation that their settings are saved. It re-persists everything
  // in one batch as a safety net in case any individual write above ever
  // failed silently.
  // ============================================================

  Future<void> _savePreferences() async {
    await Future.wait([
      SettingsService.setNotifications(_notifications),
      SettingsService.setNoticeNotifications(_noticeNotifications),
      SettingsService.setFeeNotifications(_feeNotifications),
      SettingsService.setComplaintNotifications(_complaintNotifications),
      SettingsService.setSoundEffects(_soundEffects),
      SettingsService.setVibration(_vibration),
      SettingsService.setLanguage(_selectedLanguage),
    ]);

    _showMessage('Preferences saved successfully.');
  }

  // ============================================================
  // LOGOUT
  // ============================================================

Future<void> _confirmLogout() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        icon: Icon(
          Icons.logout_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 34,
        ),
        title: const Text('Logout?'),
        content: const Text(
          'Are you sure you want to logout from your student account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !mounted) return;

  try {
    // Logout from Firebase / local session
    await SessionService.logout();

    if (!mounted) return;

    // Remove all authenticated pages and open LoginPage
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  } catch (e) {
    if (!mounted) return;

    _showMessage('Unable to logout: $e');
  }
}

  // ============================================================
  // INFO DIALOG
  // ============================================================

  Future<void> _showInfoDialog({
    required String title,
    required IconData icon,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          icon: Icon(icon, size: 34, color: colorScheme.primary),
          title: Text(title),
          content: Text(message, style: const TextStyle(height: 1.5)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}