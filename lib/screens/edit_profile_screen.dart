import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import '../config.dart';
import '../services/auth_service.dart';
import '../widgets/responsive.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _educationOrJobController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _socialGithubController = TextEditingController();
  final _socialLinkedinController = TextEditingController();
  final _skillsController = TextEditingController();
  final _interestsController = TextEditingController();
  final _availabilityController = TextEditingController();
  String _experienceLevel = 'BEGINNER';
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate with existing values
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final profile = user?.profile;
    if (profile != null) {
      _bioController.text = profile.bio ?? '';
      _locationController.text = profile.location ?? '';
      _educationOrJobController.text = profile.educationOrJob ?? '';
      _emergencyNameController.text = profile.emergencyName ?? '';
      _emergencyContactController.text = profile.emergencyContact ?? '';
      _socialGithubController.text = profile.socialGithub ?? '';
      _socialLinkedinController.text = profile.socialLinkedin ?? '';
      _skillsController.text = profile.skills.join(', ');
      _interestsController.text = profile.interests.join(', ');
      _availabilityController.text = profile.availability.join(', ');
      _experienceLevel = profile.experienceLevel;
      _avatarUrl = profile.avatarUrl;
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _locationController.dispose();
    _educationOrJobController.dispose();
    _emergencyNameController.dispose();
    _emergencyContactController.dispose();
    _socialGithubController.dispose();
    _socialLinkedinController.dispose();
    _skillsController.dispose();
    _interestsController.dispose();
    _availabilityController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    final skillsList = _skillsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final interestsList = _interestsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final availabilityList = _availabilityController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final result = await authService.updateProfile(
      bio: _bioController.text.trim(),
      location: _locationController.text.trim(),
      educationOrJob: _educationOrJobController.text.trim(),
      emergencyName: _emergencyNameController.text.trim(),
      emergencyContact: _emergencyContactController.text.trim(),
      socialGithub: _socialGithubController.text.trim(),
      socialLinkedin: _socialLinkedinController.text.trim(),
      skills: skillsList,
      interests: interestsList,
      avatarUrl: _avatarUrl,
      experienceLevel: _experienceLevel,
      availability: availabilityList,
    );

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(
              0xFF0E6C4A,
            ), // Voluntree Primary/Secondary Green
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update profile'),
            backgroundColor: const Color(0xFFBA1A1A), // Voluntree Error Red
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadAvatar(
    BuildContext context,
    ImageSource source,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    bool hasPermission = false;

    try {
      if (kIsWeb) {
        // Browsers gate camera/file access through their own prompts.
        hasPermission = true;
      } else if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (status.isGranted) {
          hasPermission = true;
        } else if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
      } else {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          final status = await Permission.photos.request();
          if (status.isGranted || status.isLimited) {
            hasPermission = true;
          } else if (status.isPermanentlyDenied) {
            await openAppSettings();
          }
        } else if (defaultTargetPlatform == TargetPlatform.android) {
          final status = await Permission.photos.request();
          if (status.isGranted) {
            hasPermission = true;
          } else {
            final storageStatus = await Permission.storage.request();
            if (storageStatus.isGranted) {
              hasPermission = true;
            } else if (storageStatus.isPermanentlyDenied) {
              await openAppSettings();
            }
          }
        } else {
          hasPermission = true;
        }
      }
    } catch (e) {
      debugPrint('[PERMISSION ERROR] $e');
      hasPermission = true; // fallback
    }

    if (!hasPermission) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Permission denied. Please grant permission in settings to upload.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isUploadingAvatar = true;
      });

      final bytes = await image.readAsBytes();
      final uploadedUrl = await authService.uploadProfileImage(
        bytes,
        image.name,
      );

      if (uploadedUrl != null) {
        if (!mounted) return;
        setState(() {
          _avatarUrl = AppConfig.formatMediaUrl(uploadedUrl);
          _isUploadingAvatar = false;
        });
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Avatar uploaded successfully! Click Save Changes to apply.',
              ),
              backgroundColor: Color(0xFF0E6C4A),
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('[AVATAR UPLOAD ERROR] $e');
    }

    if (!mounted) return;
    setState(() {
      _isUploadingAvatar = false;
    });
    if (mounted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to upload avatar. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showAvatarPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickAndUploadAvatar(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickAndUploadAvatar(context, ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = Provider.of<AuthService>(context).isLoading;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Edit Profile Details',
          style: GoogleFonts.plusJakartaSans(
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ResponsiveCenter(
        maxWidth: 760,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tell the community about yourself',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Profile Picture Uploader
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 54,
                            backgroundColor: const Color(0xFFE8EFF1),
                            backgroundImage:
                                _avatarUrl != null && _avatarUrl!.isNotEmpty
                                ? NetworkImage(_avatarUrl!)
                                : null,
                            child: _avatarUrl == null || _avatarUrl!.isEmpty
                                ? Icon(
                                    Icons.person,
                                    size: 54,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                          ),
                          if (_isUploadingAvatar)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _showAvatarPickerOptions(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bio field
                    _buildSectionHeader('Biography'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 250,
                      decoration: _buildInputDecoration(
                        'Describe your passion, experiences, or volunteering goals...',
                        Icons.description_outlined,
                        theme,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // Location & Occupation
                    _buildSectionHeader('Personal Details'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _locationController,
                      decoration: _buildInputDecoration(
                        'Location (e.g. San Francisco, CA)',
                        Icons.location_on_outlined,
                        theme,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _educationOrJobController,
                      decoration: _buildInputDecoration(
                        'Education or Occupation (e.g. Student at Stanford)',
                        Icons.work_outline,
                        theme,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // Volunteer Profile Details
                    _buildSectionHeader('Volunteer Profile Details'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _skillsController,
                      decoration: _buildInputDecoration(
                        'Skills (comma-separated, e.g. teaching, first aid)',
                        Icons.bolt,
                        theme,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _interestsController,
                      decoration: _buildInputDecoration(
                        'Interests (comma-separated, e.g. environment, health)',
                        Icons.favorite_border,
                        theme,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _availabilityController,
                      decoration: _buildInputDecoration(
                        'Availability (comma-separated, e.g. weekends, evenings)',
                        Icons.calendar_month,
                        theme,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // Experience Level Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4FAFD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE8EFF1),
                          width: 1.5,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _experienceLevel,
                          decoration: const InputDecoration(
                            labelText: 'Experience Level',
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.star_outline,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'BEGINNER',
                              child: Text('Beginner'),
                            ),
                            DropdownMenuItem(
                              value: 'INTERMEDIATE',
                              child: Text('Intermediate'),
                            ),
                            DropdownMenuItem(
                              value: 'EXPERIENCED',
                              child: Text('Experienced'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _experienceLevel = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Emergency contact details
                    _buildSectionHeader('Emergency Contact (Private)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emergencyNameController,
                      decoration: _buildInputDecoration(
                        'Contact Name',
                        Icons.person_outline,
                        theme,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emergencyContactController,
                      keyboardType: TextInputType.phone,
                      decoration: _buildInputDecoration(
                        'Contact Phone Number',
                        Icons.phone_outlined,
                        theme,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // Social handles
                    _buildSectionHeader('Social Profiles'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _socialGithubController,
                      decoration: _buildInputDecoration(
                        'GitHub URL (e.g. github.com/username)',
                        Icons.code,
                        theme,
                      ),
                      style: const TextStyle(fontSize: 14),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _socialLinkedinController,
                      decoration: _buildInputDecoration(
                        'LinkedIn URL (e.g. linkedin.com/in/username)',
                        Icons.link,
                        theme,
                      ),
                      style: const TextStyle(fontSize: 14),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 40),

                    // Save button
                    ElevatedButton(
                      onPressed: isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Save Changes',
                        style: GoogleFonts.plusJakartaSans(
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            if (isLoading)
              Container(
                color: Colors.white30,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF161D1F),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String hintText,
    IconData icon,
    ThemeData theme,
  ) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF4FAFD),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8EFF1), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8EFF1), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }
}
