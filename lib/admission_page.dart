import 'package:flutter/material.dart';
import 'app_urls.dart';
import 'link_utils.dart';
import 'services/api_service.dart';

class AdmissionPage extends StatefulWidget {
  const AdmissionPage({super.key});

  @override
  State<AdmissionPage> createState() => _AdmissionPageState();
}

class _AdmissionPageState extends State<AdmissionPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _collegeIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _course;
  String? _yearOfStudy;
  String? _department;
  String? _hostelType;
  String? _roomType;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _collegeIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        centerTitle: false,
        title: const Text(
          'Hostel Admission',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSectionCard(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Information',
                      subtitle: 'Enter your basic details',
                      children: [
                        _buildTextField(
                          'Full Name*',
                          'Enter your full name',
                          controller: _fullNameController,
                          icon: Icons.person_outline_rounded,
                        ),
                        _buildTextField(
                          'College ID*',
                          'Enter your college ID',
                          controller: _collegeIdController,
                          icon: Icons.badge_outlined,
                        ),
                        _buildTextField(
                          'Email Address*',
                          'Enter your email address',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          icon: Icons.email_outlined,
                        ),
                        _buildTextField(
                          'Phone Number*',
                          'Enter your phone number',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          icon: Icons.phone_outlined,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _buildSectionCard(
                      icon: Icons.school_outlined,
                      title: 'Academic Information',
                      subtitle: 'Tell us about your academic details',
                      children: [
                        _buildDropdownField(
                          'Course*',
                          [
                            'B.Tech',
                            'M.Tech',
                            'BCA',
                            'MCA',
                            'Other',
                          ],
                          icon: Icons.menu_book_outlined,
                          onChanged: (value) => setState(() {
                            _course = value;
                          }),
                        ),
                        _buildDropdownField(
                          'Year of Study*',
                          [
                            'First Year',
                            'Second Year',
                            'Third Year',
                            'Fourth Year',
                          ],
                          icon: Icons.calendar_today_outlined,
                          onChanged: (value) => setState(() {
                            _yearOfStudy = value;
                          }),
                        ),
                        _buildDropdownField(
                          'Department*',
                          [
                            'Computer Science',
                            'Information Technology',
                            'Mechanical',
                            'Civil',
                            'Other',
                          ],
                          icon: Icons.account_tree_outlined,
                          onChanged: (value) => setState(() {
                            _department = value;
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _buildSectionCard(
                      icon: Icons.apartment_outlined,
                      title: 'Hostel Preferences',
                      subtitle: 'Choose your preferred accommodation',
                      children: [
                        _buildDropdownField(
                          'Hostel Type*',
                          [
                            'Boys Hostel',
                            'Girls Hostel',
                          ],
                          icon: Icons.home_work_outlined,
                          onChanged: (value) => setState(() {
                            _hostelType = value;
                          }),
                        ),
                        _buildDropdownField(
                          'Room Type*',
                          [
                            'Single Occupancy',
                            'Double Occupancy',
                            'Triple Occupancy',
                          ],
                          icon: Icons.bed_outlined,
                          onChanged: (value) => setState(() {
                            _roomType = value;
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSubmitButton(),

                    const SizedBox(height: 14),

                    _buildWebsiteButton(),

                    const SizedBox(height: 10),

                    Text(
                      'Please make sure all information is correct before submitting.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
      decoration: BoxDecoration(
        color: Colors.blue[800],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.home_work_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Apply for Hostel Accommodation',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fill in your details and submit your hostel application.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION CARD
  // ------------------------------------------------------------

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: Colors.blue[800],
                  size: 24,
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TEXT FIELD
  // ------------------------------------------------------------

  Widget _buildTextField(
    String label,
    String hint, {
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            size: 21,
            color: Colors.blue[700],
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.blue[800]!,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Colors.redAccent,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Colors.redAccent,
              width: 1.5,
            ),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // DROPDOWN
  // ------------------------------------------------------------

  Widget _buildDropdownField(
    String label,
    List<String> items, {
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            size: 21,
            color: Colors.blue[700],
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.blue[800]!,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Colors.redAccent,
            ),
          ),
        ),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // SUBMIT BUTTON
  // ------------------------------------------------------------

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitAdmission,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[800],
          disabledBackgroundColor: Colors.blue[300],
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.blue.withValues(alpha: 0.30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isSubmitting
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                )
              : const Row(
                  key: ValueKey('submit'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.send_rounded,
                      size: 21,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Submit Application',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // WEBSITE BUTTON
  // ------------------------------------------------------------

  Widget _buildWebsiteButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () =>
            launchExternalUrl(context, AppUrls.ritCollegeHome),
        icon: Icon(
          Icons.open_in_new_rounded,
          color: Colors.blue[800],
          size: 20,
        ),
        label: Text(
          'Visit RIT College Website',
          style: TextStyle(
            color: Colors.blue[800],
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Colors.blue[300]!,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SUBMIT LOGIC — KEPT UNCHANGED
  // ------------------------------------------------------------

  Future<void> _submitAdmission() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isSubmitting = true);

    try {
      final message = await ApiService.submitAdmission(
        fullName: _fullNameController.text.trim(),
        collegeId: _collegeIdController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        course: _course ?? '',
        yearOfStudy: _yearOfStudy ?? '',
        department: _department ?? '',
        hostelType: _hostelType ?? '',
        roomType: _roomType ?? '',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: Colors.red[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}