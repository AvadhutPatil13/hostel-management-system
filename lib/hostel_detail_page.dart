import 'package:flutter/material.dart';
import 'app_urls.dart';
import 'link_utils.dart';

enum HostelDetailKind { indra, boysBlock, girlsFairy, girlsHaripriya }

class HostelDetailPage extends StatelessWidget {
  const HostelDetailPage({super.key, required this.kind});

  final HostelDetailKind kind;

  // ============================================================
  // HOSTEL TITLES
  // ============================================================

  String get _title {
    switch (kind) {
      case HostelDetailKind.indra:
        return 'Indra (New Boys Hostel)';
      case HostelDetailKind.boysBlock:
        return 'Boys Hostel (A, B, C, D)';
      case HostelDetailKind.girlsFairy:
        return 'Girls Hostel (Fairy)';
      case HostelDetailKind.girlsHaripriya:
        return 'Girls Hostel (Haripriya)';
    }
  }

  // ============================================================
  // HERO IMAGE
  // ============================================================

  String get _heroAsset {
    switch (kind) {
      case HostelDetailKind.indra:
        return 'assets/images/NewHostel.webp';
      case HostelDetailKind.boysBlock:
        return 'assets/images/Hostel View.webp';
      case HostelDetailKind.girlsFairy:
        return 'assets/images/GirlsH1.webp';
      case HostelDetailKind.girlsHaripriya:
        return 'assets/images/Girls_Hostel1.webp';
    }
  }

  // ============================================================
  // HEADING
  // ============================================================

  String get _heading {
    switch (kind) {
      case HostelDetailKind.indra:
        return 'Hostel information';
      case HostelDetailKind.boysBlock:
        return 'Campus & facilities';
      case HostelDetailKind.girlsFairy:
        return 'Girls Hostel (Fairy)';
      case HostelDetailKind.girlsHaripriya:
        return 'Girls Hostel (Haripriya)';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      appBar: AppBar(
        title: Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),

      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          // ======================================================
          // HERO IMAGE
          // ======================================================

          _buildHeroSection(context),

          // ======================================================
          // MAIN CONTENT
          // ======================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hostel title
                Text(
                  _heading,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                ..._bodyWidgets(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO SECTION
  // ============================================================

  Widget _buildHeroSection(BuildContext context) {
    return SizedBox(
      height: 270,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _heroAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade300,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 60,
                  color: Colors.grey,
                ),
              );
            },
          ),

          // Dark gradient for readability
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.25),
                  Colors.black.withOpacity(0.78),
                ],
              ),
            ),
          ),

          // Hostel information over image
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _hostelType,
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBTITLE
  // ============================================================

  String get _subtitle {
    switch (kind) {
      case HostelDetailKind.indra:
        return 'Comfortable student accommodation with modern facilities and essential services.';

      case HostelDetailKind.boysBlock:
        return 'A well-equipped residential facility designed for comfortable student living.';

      case HostelDetailKind.girlsFairy:
        return 'A secure and comfortable residential facility with essential student amenities.';

      case HostelDetailKind.girlsHaripriya:
        return 'A comfortable girls hostel offering a secure and student-friendly environment.';
    }
  }

  // ============================================================
  // HOSTEL TYPE LABEL
  // ============================================================

  String get _hostelType {
    switch (kind) {
      case HostelDetailKind.indra:
        return 'BOYS HOSTEL';

      case HostelDetailKind.boysBlock:
        return 'BOYS HOSTEL';

      case HostelDetailKind.girlsFairy:
        return 'GIRLS HOSTEL';

      case HostelDetailKind.girlsHaripriya:
        return 'GIRLS HOSTEL';
    }
  }

  // ============================================================
  // BODY CONTENT
  // ============================================================

  List<Widget> _bodyWidgets(BuildContext context) {
    switch (kind) {
      case HostelDetailKind.indra:
        return [
          _buildDescriptionCard(
            context,
            icon: Icons.home_work_outlined,
            title: 'About the hostel',
            description:
                'Indra Hostel provides comfortable accommodation for students '
                'with modern amenities and facilities. The hostel is equipped '
                'with all necessary services to ensure a pleasant stay for students.',
          ),

          const SizedBox(height: 18),

          _buildFacilitiesCard(
            context,
            title: 'Facilities & services',
            items: const [
              'Free WiFi access',
              '24/7 security',
              'Modern mess facility',
              'Laundry services',
              'Study room',
              'Recreation room',
            ],
          ),

          const SizedBox(height: 20),

          _buildYoutubeButton(
            context,
            icon: Icons.play_circle_outline,
            label: 'Watch 3D View on YouTube',
            onPressed: () => launchExternalUrl(
              context,
              AppUrls.indraHostelYoutube,
            ),
          ),
        ];

      case HostelDetailKind.boysBlock:
        return [
          _buildFacilitiesCard(
            context,
            title: 'Basic facilities',
            items: const [
              'Free WiFi access',
              '24/7 security',
              'CCTV surveillance',
              'Power backup',
            ],
          ),

          const SizedBox(height: 18),

          _buildFacilitiesCard(
            context,
            title: 'Room amenities',
            items: const [
              'Single / double occupancy',
              'Attached bathroom',
              'Study table & chair',
              'Wardrobe & storage',
            ],
          ),

          const SizedBox(height: 20),

          _buildYoutubeButton(
            context,
            icon: Icons.video_library_outlined,
            label: 'Watch Campus View on YouTube',
            onPressed: () => launchExternalUrl(
              context,
              AppUrls.boysHostelCampusYoutube,
            ),
          ),
        ];

      case HostelDetailKind.girlsFairy:
        return [
          _buildFacilitiesCard(
            context,
            title: 'Basic facilities',
            items: const [
              'Free WiFi access',
              '24/7 security',
              'CCTV surveillance',
              'Power backup',
              'Common study room',
            ],
          ),

          const SizedBox(height: 18),

          _buildFacilitiesCard(
            context,
            title: 'Room amenities',
            items: const [
              'Triple occupancy rooms',
              'Attached bathroom',
              'Study table & chair',
              'Wardrobe & storage',
              'Reading lamp',
            ],
          ),

          const SizedBox(height: 20),

          _buildAdditionalImage(
            context,
            'assets/images/GirlsH1.webp',
          ),
        ];

      case HostelDetailKind.girlsHaripriya:
        return [
          _buildFacilitiesCard(
            context,
            title: 'Basic facilities',
            items: const [
              'Free WiFi access',
              '24/7 security',
              'CCTV surveillance',
              'Power backup',
              'Common recreation room',
            ],
          ),

          const SizedBox(height: 18),

          _buildFacilitiesCard(
            context,
            title: 'Room amenities',
            items: const [
              'Double occupancy rooms',
              'Attached bathroom',
              'Study table & chair',
              'Wardrobe & storage',
              'Reading lamp',
            ],
          ),

          const SizedBox(height: 20),

          _buildAdditionalImage(
            context,
            'assets/images/Girls_Hostel1.webp',
          ),
        ];
    }
  }

  // ============================================================
  // DESCRIPTION CARD
  // ============================================================

  Widget _buildDescriptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: Colors.blue[800],
              size: 25,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FACILITIES CARD
  // ============================================================

  Widget _buildFacilitiesCard(
    BuildContext context, {
    required String title,
    required List<String> items,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: Colors.blue[800],
                  size: 22,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          ...items.map(
            (item) => _buildFacilityItem(
              context,
              item,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FACILITY ITEM
  // ============================================================

  Widget _buildFacilityItem(
    BuildContext context,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 14,
              color: Colors.green,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // YOUTUBE BUTTON
  // ============================================================

  Widget _buildYoutubeButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
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
    );
  }

  // ============================================================
  // ADDITIONAL IMAGE
  // ============================================================

  Widget _buildAdditionalImage(
    BuildContext context,
    String asset,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.asset(
          asset,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported_outlined,
                size: 50,
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }
}