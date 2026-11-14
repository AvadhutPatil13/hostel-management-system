import 'package:flutter/material.dart';

import 'app_urls.dart';
import 'link_utils.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

// ---------------------------------------------------------
// RIT LOGO / HEADER CARD
// ---------------------------------------------------------
Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 26,
  ),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Colors.blue[800]!,
        Colors.blue[600]!,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.blue.withValues(alpha: 0.20),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  ),
  child: Column(
    children: [
      // Logo container
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/RIT logo1.webp',
          height: 150,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              height: 150,
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),
      ),

      const SizedBox(height: 20),

      const Text(
        'RIT Hostels',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),

      const SizedBox(height: 7),

      Text(
        'Hostel Management & Information',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  ),
),

            const SizedBox(height: 26),

            // ---------------------------------------------------------
            // ABOUT RIT SECTION
            // ---------------------------------------------------------
            _SectionTitle(
              icon: Icons.info_outline_rounded,
              title: 'About RIT',
              color: colorScheme.primary,
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'For official college information, history, and departments, '
                'visit the RIT website using the buttons below. These links '
                'connect directly to the official college website.',
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.55,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ---------------------------------------------------------
            // OFFICIAL WEBSITE BUTTONS
            // ---------------------------------------------------------
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: () => launchExternalUrl(
                  context,
                  AppUrls.ritCollegeAbout,
                ),
                icon: const Icon(Icons.school_outlined),
                label: const Text(
                  'About RIT',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () => launchExternalUrl(
                  context,
                  AppUrls.ritCollegeHome,
                ),
                icon: const Icon(Icons.language_rounded),
                label: const Text(
                  'Visit RIT Website',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[800],
                  side: BorderSide(
                    color: Colors.blue[800]!,
                    width: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ---------------------------------------------------------
            // IN THIS APP SECTION
            // ---------------------------------------------------------
            _SectionTitle(
              icon: Icons.apps_rounded,
              title: 'In This App',
              color: colorScheme.primary,
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue[50]!,
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                children: [
                  _FeatureRow(
                    icon: Icons.apartment_rounded,
                    title: 'Hostels',
                    description: 'Browse available hostel information',
                  ),
                  const SizedBox(height: 16),
                  _FeatureRow(
                    icon: Icons.home_work_outlined,
                    title: 'Facilities',
                    description: 'Explore hostel facilities and amenities',
                  ),
                  const SizedBox(height: 16),
                  _FeatureRow(
                    icon: Icons.restaurant_outlined,
                    title: 'Mess Timings',
                    description: 'Check daily mess and meal timings',
                  ),
                  const SizedBox(height: 16),
                  _FeatureRow(
                    icon: Icons.gavel_rounded,
                    title: 'Hostel Rules',
                    description: 'View important hostel guidelines',
                  ),
                  const SizedBox(height: 16),
                  _FeatureRow(
                    icon: Icons.contact_phone_outlined,
                    title: 'Contact Details',
                    description: 'Find important hostel contact information',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ---------------------------------------------------------
            // APP DESCRIPTION
            // ---------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: colorScheme.primary,
                    size: 25,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'The RIT Hostels app brings important hostel '
                      'information together in one convenient place, '
                      'making it easier for students to access the '
                      'information they need.',
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ---------------------------------------------------------
            // FOOTER
            // ---------------------------------------------------------
            Column(
              children: [
                Icon(
                  Icons.apartment_rounded,
                  color: Colors.blue[700],
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  'RIT Hostels',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hostel Management Application',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// SECTION TITLE
// =====================================================================

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// FEATURE ROW
// =====================================================================

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: colorScheme.primary,
            size: 22,
          ),
        ),

        const SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}