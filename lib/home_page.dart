import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'about_page.dart';
import 'admission_page.dart';
import 'contact_page.dart';
import 'hostel_detail_page.dart';
import 'link_utils.dart';
import 'login_page.dart';
import 'registration_page.dart';
import 'hostels_page.dart';
import 'events_page.dart';
import 'student/pages/student_available_rooms_page.dart';
import 'mess_facility_page.dart';
import 'rules_regulations_page.dart';
import 'navigation_observer.dart';
import 'services/session_service.dart';
import 'admin/admin_shell.dart';
import 'student/student_shell.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  Map<String, dynamic>? _currentUser;

  // ============================================================
  // HOSTEL CAROUSEL
  // ============================================================

  late final PageController _hostelPageController;

  Timer? _hostelAutoSlideTimer;

  int _currentHostelIndex = 0;

  final List<Map<String, dynamic>> _hostels = [
    {
      'name': 'Indra (New Boys Hostel)',
      'shortName': 'Indra Hostel',
      'image': 'assets/images/NewHostel.webp',
      'kind': HostelDetailKind.indra,
    },
    {
      'name': 'Boys Hostel (A, B, C, D)',
      'shortName': 'Boys Hostel',
      'image': 'assets/images/Hostel View.webp',
      'kind': HostelDetailKind.boysBlock,
    },
    {
      'name': 'Girls Hostel (Fairy)',
      'shortName': 'Fairy Hostel',
      'image': 'assets/images/GirlsH1.webp',
      'kind': HostelDetailKind.girlsFairy,
    },
    {
      'name': 'Girls Hostel (Haripriya)',
      'shortName': 'Haripriya Hostel',
      'image': 'assets/images/Girls_Hostel1.webp',
      'kind': HostelDetailKind.girlsHaripriya,
    },
  ];

  @override
  void initState() {
    super.initState();

    _hostelPageController = PageController(
      viewportFraction: 0.82,
    );

    _loadSession();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startHostelAutoSlide();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);

    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _hostelAutoSlideTimer?.cancel();
    _hostelPageController.dispose();

    routeObserver.unsubscribe(this);

    super.dispose();
  }

  @override
  void didPopNext() {
    _loadSession();
  }

  // ============================================================
  // SESSION
  // ============================================================

  Future<void> _loadSession() async {
    final user = await SessionService.getCurrentUser();

    if (!mounted) return;

    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _openLogin() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => const LoginPage(),
      ),
    );

    await _loadSession();
  }

  Future<void> _openRegister() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => const RegistrationPage(),
      ),
    );

    await _loadSession();
  }

  Future<void> _logout() async {
    await SessionService.clear();

    if (!mounted) return;

    setState(() {
      _currentUser = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            SizedBox(width: 10),
            Text('Logged out successfully'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // HOSTEL AUTO SLIDER
  // ============================================================

  void _startHostelAutoSlide() {
    _hostelAutoSlideTimer?.cancel();

    _hostelAutoSlideTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (!_hostelPageController.hasClients) return;

        final nextIndex =
            (_currentHostelIndex + 1) % _hostels.length;

        _hostelPageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeInOutCubic,
        );
      },
    );
  }

  void _pauseHostelAutoSlide() {
    _hostelAutoSlideTimer?.cancel();
  }

  void _resumeHostelAutoSlide() {
    _startHostelAutoSlide();
  }

  void _goToHostel(int index) {
    if (!_hostelPageController.hasClients) return;

    _hostelPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  void _nextHostel() {
    final nextIndex =
        (_currentHostelIndex + 1) % _hostels.length;

    _goToHostel(nextIndex);
  }

  void _previousHostel() {
    final previousIndex =
        (_currentHostelIndex - 1 + _hostels.length) %
            _hostels.length;

    _goToHostel(previousIndex);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: _buildAppBar(),

      endDrawer: _buildDrawer(),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildHeroSection(context),
            _buildHostelsSection(context),
            _buildFacilitiesSection(context),
            _buildPhotosSection(context),
            _buildMessBanner(context),
            _buildReserveBanner(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black.withOpacity(0.20),
      elevation: 0,
      scrolledUnderElevation: 0,

      leading: Padding(
        padding: const EdgeInsets.only(
          left: 12,
          top: 5,
          bottom: 5,
        ),
        child: Image.asset(
          'assets/images/RIT logo1.webp',
          fit: BoxFit.contain,
        ),
      ),

      title: Text(
        'RIT HOSTEL',
        style: GoogleFonts.playfairDisplay(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),

      actions: [
        if (_currentUser != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 130,
                ),
                child: Text(
                  _currentUser?['name']?.toString() ??
                      'Logged in',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white,
            ),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],

        Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 29,
              ),
              tooltip: 'Menu',
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // DRAWER
  // ============================================================

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade900,
                  Colors.blue.shade600,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'RIT HOSTEL',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 7),

                if (_currentUser != null) ...[
                  Text(
                    _currentUser?['name']?.toString() ??
                        'Account',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 3),

                  Text(
                    _currentUser?['email']?.toString() ?? '',
                    style: GoogleFonts.roboto(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  Text(
                    'Welcome to RIT Hostel',
                    style: GoogleFonts.roboto(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),

          _buildDrawerItem(
            context,
            Icons.home_rounded,
            'Home',
            null,
          ),

          _buildDrawerItem(
            context,
            Icons.hotel_rounded,
            'Hostels',
            const HostelsPage(),
          ),

          _buildDrawerItem(
            context,
            Icons.info_outline_rounded,
            'About',
            const AboutPage(),
          ),

          _buildDrawerItem(
            context,
            Icons.assignment_outlined,
            'Admission',
            const AdmissionPage(),
          ),

          _buildDrawerItem(
            context,
            Icons.fact_check_outlined,
            'Rules & regulations',
            const RulesRegulationsPage(),
          ),

          _buildDrawerItem(
            context,
            Icons.contact_mail_outlined,
            'Contact',
            const ContactPage(),
          ),

          _buildDrawerItem(
            context,
            Icons.event_outlined,
            'Events',
            const EventsPage(),
          ),

          const Divider(),

          if (_currentUser == null) ...[
            ListTile(
              leading: const Icon(Icons.login_rounded),
              title: const Text('Login'),
              onTap: () async {
                Navigator.pop(context);
                await _openLogin();
              },
            ),

            ListTile(
              leading: const Icon(
                Icons.person_add_alt_1_rounded,
              ),
              title: const Text('Register'),
              onTap: () async {
                Navigator.pop(context);
                await _openRegister();
              },
            ),
          ] else ...[
            if ((_currentUser?['role']?.toString() ?? '') !=
                'admin')
              ListTile(
                leading: const Icon(Icons.school_rounded),
                title: const Text('Student'),
                onTap: () async {
                  Navigator.pop(context);

                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const StudentShell(),
                    ),
                  );

                  await _loadSession();
                },
              ),

            if ((_currentUser?['role']?.toString() ?? '') ==
                'admin')
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_rounded,
                ),
                title: const Text('Admin'),
                onTap: () async {
                  Navigator.pop(context);

                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminShell(),
                    ),
                  );

                  await _loadSession();
                },
              ),

            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                await _logout();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    Widget? page,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: () {
        Navigator.pop(context);

        if (page != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => page,
            ),
          );
        }
      },
    );
  }

  // ============================================================
  // HERO SECTION
  // ============================================================

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      height: 640,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            'assets/images/Hostel_Mangement1.webp',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.35),
              Colors.black.withOpacity(0.55),
              Colors.black.withOpacity(0.72),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.30),
                      ),
                    ),
                    child: Text(
                      'WELCOME TO RIT HOSTELS',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  Text(
                    'A Best Place\nfor Students',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 43,
                      height: 1.12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 18),

                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 650,
                    ),
                    child: Text(
                      'Comfortable living, a safe environment and a community that feels like home.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (_currentUser == null)
                    ElevatedButton.icon(
                      onPressed: _openLogin,
                      icon: const Icon(
                        Icons.login_rounded,
                        size: 19,
                      ),
                      label: const Text('Reserve Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade900,
                        elevation: 8,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      'You are logged in as '
                      '${_currentUser?['name'] ?? 'a user'}.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: () {
                        final role =
                            _currentUser?['role']
                                    ?.toString() ??
                                'student';

                        if (role == 'admin') {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const AdminShell(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const StudentShell(),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        _currentUser?['role']?.toString() ==
                                'admin'
                            ? Icons.admin_panel_settings_rounded
                            : Icons.dashboard_rounded,
                      ),
                      label: Text(
                        _currentUser?['role']?.toString() ==
                                'admin'
                            ? 'Go to admin panel'
                            : 'View student dashboard',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade900,
                        elevation: 8,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HOSTELS SECTION
  // ============================================================

  Widget _buildHostelsSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 800;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: isWide ? 70 : 55,
            bottom: isWide ? 55 : 45,
          ),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                'assets/images/sliderjj.webp',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.50),
                ),
              ),

              Column(
                children: [
                  _buildSectionHeading(
                    title: 'Our Hostels',
                    subtitle:
                        'Explore comfortable and secure accommodation options designed for students.',
                    light: true,
                  ),

                  const SizedBox(height: 38),

                  SizedBox(
                    height: isWide ? 470 : 430,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // ==================================================
                        // CAROUSEL
                        // ==================================================

                        Listener(
                          onPointerDown: (_) {
                            _pauseHostelAutoSlide();
                          },
                          onPointerUp: (_) {
                            _resumeHostelAutoSlide();
                          },
                          onPointerCancel: (_) {
                            _resumeHostelAutoSlide();
                          },
                          child: PageView.builder(
                            controller:
                                _hostelPageController,
                            itemCount: _hostels.length,
                            physics:
                                const BouncingScrollPhysics(),
                            onPageChanged: (index) {
                              setState(() {
                                _currentHostelIndex = index;
                              });
                            },
                            itemBuilder:
                                (context, index) {
                              final hostel =
                                  _hostels[index];

                              return AnimatedBuilder(
                                animation:
                                    _hostelPageController,
                                builder:
                                    (context, child) {
                                  double scale = 1.0;

                                  if (_hostelPageController
                                      .position
                                      .haveDimensions) {
                                    final page =
                                        _hostelPageController
                                            .page ??
                                            _currentHostelIndex
                                                .toDouble();

                                    final distance =
                                        (page - index)
                                            .abs();

                                    scale =
                                        (1 -
                                                (distance *
                                                    0.10))
                                            .clamp(
                                              0.88,
                                              1.0,
                                            );
                                  }

                                  return Transform.scale(
                                    scale: scale,
                                    child: Padding(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 7,
                                        vertical: 10,
                                      ),
                                      child:
                                          _buildHostelCard(
                                        context,
                                        hostel['name']
                                            as String,
                                        hostel['image']
                                            as String,
                                        hostel['kind']
                                            as HostelDetailKind,
                                        isActive:
                                            index ==
                                                _currentHostelIndex,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        // ==================================================
                        // PREVIOUS BUTTON
                        // ==================================================

                        if (isWide)
                          Positioned(
                            left: 20,
                            child: _buildCarouselButton(
                              icon: Icons
                                  .arrow_back_ios_new_rounded,
                              onTap: _previousHostel,
                            ),
                          ),

                        // ==================================================
                        // NEXT BUTTON
                        // ==================================================

                        if (isWide)
                          Positioned(
                            right: 20,
                            child: _buildCarouselButton(
                              icon: Icons
                                  .arrow_forward_ios_rounded,
                              onTap: _nextHostel,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ========================================================
                  // DOT INDICATORS
                  // ========================================================

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: List.generate(
                      _hostels.length,
                      (index) {
                        final bool isActive =
                            index == _currentHostelIndex;

                        return GestureDetector(
                          onTap: () => _goToHostel(index),
                          child: AnimatedContainer(
                            duration: const Duration(
                              milliseconds: 300,
                            ),
                            curve: Curves.easeOut,
                            width: isActive ? 28 : 8,
                            height: 8,
                            margin:
                                const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white
                                      .withOpacity(0.35),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swipe_rounded,
                        color: Colors.white.withOpacity(0.65),
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Swipe to explore hostels',
                        style: GoogleFonts.roboto(
                          color:
                              Colors.white.withOpacity(0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '${_currentHostelIndex + 1} / ${_hostels.length}',
                    style: GoogleFonts.roboto(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCarouselButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withOpacity(0.35),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 19,
          ),
        ),
      ),
    );
  }

  Widget _buildHostelCard(
    BuildContext context,
    String name,
    String imagePath,
    HostelDetailKind kind, {
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      elevation: isActive ? 16 : 8,
      shadowColor: Colors.black.withOpacity(0.40),
      child: InkWell(
        onTap: () {
          _pauseHostelAutoSlide();

          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => HostelDetailPage(
                kind: kind,
              ),
            ),
          ).then((_) {
            _resumeHostelAutoSlide();
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ============================================================
            // IMAGE
            // ============================================================

            Image.asset(
              imagePath,
              fit: BoxFit.cover,
            ),

            // ============================================================
            // DARK GRADIENT
            // ============================================================

            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.08),
                    Colors.transparent,
                    Colors.black.withOpacity(0.88),
                  ],
                  stops: const [
                    0.0,
                    0.40,
                    1.0,
                  ],
                ),
              ),
            ),

            // ============================================================
            // TOP BADGE
            // ============================================================

            Positioned(
              top: 18,
              left: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.42),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.apartment_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'RIT HOSTEL',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ============================================================
            // ACTIVE INDICATOR
            // ============================================================

            if (isActive)
              Positioned(
                top: 18,
                right: 18,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            // ============================================================
            // BOTTOM CONTENT
            // ============================================================

            Positioned(
              left: 22,
              right: 22,
              bottom: 22,
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 9),

                        Row(
                          children: [
                            const Icon(
                              Icons.touch_app_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to view details',
                              style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // ========================================================
                  // ARROW
                  // ========================================================

                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.blue.shade900,
                      size: 23,
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

  // ============================================================
  // SECTION HEADING
  // ============================================================

  Widget _buildSectionHeading({
    required String title,
    required String subtitle,
    bool light = false,
  }) {
    final titleColor =
        light ? Colors.white : Colors.black87;

    final subtitleColor =
        light ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            width: 50,
            height: 3,
            decoration: BoxDecoration(
              color: light
                  ? Colors.white
                  : Colors.blue.shade700,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 15),

          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 750,
            ),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                color: subtitleColor,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FACILITIES
  // ============================================================

  Widget _buildFacilitiesSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 55,
        horizontal: 20,
      ),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            'assets/images/BGF.webp',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          _buildSectionHeading(
            title: 'Our Facilities',
            subtitle:
                'Everything students need for a comfortable and convenient hostel experience.',
            light: true,
          ),

          const SizedBox(height: 30),

          _buildFacilityItem(
            context,
            'assets/images/facilities/Medical.webp',
            'Medical facility',
            '8PM–10PM (Mon–Sat), 24/7 emergency',
            onTap: () => _showMedicalInfo(context),
          ),

          _buildFacilityItem(
            context,
            'assets/images/facilities/mess.webp',
            'Mess facility',
            'Hygienic and nutritious meals served three times a day',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const MessFacilityPage(),
                ),
              );
            },
          ),

          _buildFacilityItem(
            context,
            'assets/images/facilities/laundry.webp',
            'Laundry facility',
            'Modern washing machines and dryers',
            onTap: () => _showSimpleInfoDialog(
              context,
              title: 'Laundry facility',
              body:
                  'Modern washing machines and dryers are available for students’ convenience.',
            ),
          ),

          _buildFacilityItem(
            context,
            'assets/images/facilities/wifi.webp',
            'Free WiFi',
            'High-speed internet connectivity 24/7',
            onTap: () => _showSimpleInfoDialog(
              context,
              title: 'Free WiFi',
              body:
                  'High-speed internet connectivity is available 24/7 throughout the hostel premises.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityItem(
    BuildContext context,
    String imagePath,
    String title,
    String desc, {
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 13,
      ),
      elevation: 5,
      shadowColor: Colors.black.withOpacity(0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(13),
                child: Image.asset(
                  imagePath,
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      desc,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MEDICAL DIALOG
  // ============================================================

  void _showMedicalInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.medical_services_rounded,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 10),
            const Text('Medical facility'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Timings: 8PM–10PM (Mon–Sat)\n'
            'Emergency: 24/7\n'
            'Services: first aid, health check-ups',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SIMPLE INFO DIALOG
  // ============================================================

  void _showSimpleInfoDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PHOTOS
  // ============================================================

  Widget _buildPhotosSection(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        vertical: 20,
      ),
      child: const SizedBox(
        height: 620,
        child: StudentAvailableRoomsPage(),
      ),
    );
  }

  // ============================================================
  // MESS BANNER
  // ============================================================

  Widget _buildMessBanner(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  const MessFacilityPage(),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: 65,
            horizontal: 24,
          ),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                'assets/images/hero_3.webp',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 35,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
            ),
            child: Column(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white30,
                    ),
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Our Hostel Mess',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 31,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 700,
                  ),
                  child: Text(
                    'Mess of all hostels provides better quality of food. The sanitation are all in hygienic condition and provide health quality foods.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Tap for mess details',
                        style: GoogleFonts.roboto(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESERVE BANNER
  // ============================================================

  Widget _buildReserveBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 38,
        horizontal: 24,
      ),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            'assets/images/sliderjj.webp',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 22,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.40),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 600;

            if (isSmall) {
              return Column(
                children: [
                  Text(
                    'A Best Place To Stay.\nReserve Now!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 25,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 20),

                  _buildReserveButton(),
                ],
              );
            }

            return Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'A Best Place To Stay.\nReserve Now!',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 27,
                      height: 1.2,
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                _buildReserveButton(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReserveButton() {
    return OutlinedButton.icon(
      onPressed:
          _currentUser != null ? null : _openLogin,
      icon: const Icon(
        Icons.calendar_month_rounded,
        size: 18,
      ),
      label: const Text('Reserve Now'),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(
          color: Colors.white,
          width: 1.3,
        ),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 23,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(
        horizontal: 30,
        vertical: 45,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Text(
            'RIT HOSTEL',
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'A comfortable place to live, learn and grow.',
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 30),

          Container(
            constraints: const BoxConstraints(
              maxWidth: 700,
            ),
            child: Column(
              children: [
                _buildFooterContactItem(
                  icon: Icons.location_on_rounded,
                  text:
                      'Address: RIT College, Islampur 415409',
                ),

                const SizedBox(height: 13),

                InkWell(
                  onTap: () => launchPhone(
                    context,
                    '+919937159477',
                  ),
                  borderRadius:
                      BorderRadius.circular(10),
                  child: _buildFooterContactItem(
                    icon: Icons.phone_rounded,
                    text:
                        'Phone: (+91) 993 715 9477',
                    underlined: true,
                  ),
                ),

                const SizedBox(height: 13),

                InkWell(
                  onTap: () => launchEmail(
                    context,
                    'ritindia.edu@gmail.com',
                  ),
                  borderRadius:
                      BorderRadius.circular(10),
                  child: _buildFooterContactItem(
                    icon: Icons.email_rounded,
                    text:
                        'Email: ritindia.edu@gmail.com',
                    underlined: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 35),

          Divider(
            color: Colors.white.withOpacity(0.12),
          ),

          const SizedBox(height: 18),

          Text(
            'Copyright © All rights reserved',
            style: GoogleFonts.roboto(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Made by Hackers',
            style: GoogleFonts.roboto(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterContactItem({
    required IconData icon,
    required String text,
    bool underlined = false,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.blue.shade300,
            size: 18,
          ),
        ),

        const SizedBox(width: 13),

        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(top: 8),
            child: Text(
              text,
              style: GoogleFonts.roboto(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
                decoration: underlined
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}