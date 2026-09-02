import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../widgets/responsive.dart';

class CreateEventScreen extends StatefulWidget {
  final EventModel? eventToEdit;
  const CreateEventScreen({super.key, this.eventToEdit});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _volunteersController;
  late final TextEditingController _minAgeController;
  late final TextEditingController _compensationController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  String _category = 'Environmental';
  bool _isOnline = false;
  bool _isPaid = false;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  String? _bannerUrl;
  List<String> _openPositions = [];
  List<String> _perks = [];

  bool _isSaving = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    final e = widget.eventToEdit;
    _bannerUrl = e?.bannerUrl;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');
    _volunteersController = TextEditingController(
      text: e != null ? e.volunteersNeeded.toString() : '10',
    );
    _minAgeController = TextEditingController(
      text: e != null ? e.minAge.toString() : '16',
    );
    _compensationController = TextEditingController(
      text: e?.compensationDetails ?? '',
    );
    _latitudeController = TextEditingController(
      text: e?.latitude != null ? e!.latitude.toString() : '',
    );
    _longitudeController = TextEditingController(
      text: e?.longitude != null ? e!.longitude.toString() : '',
    );
    _openPositions = e?.openPositions != null
        ? List<String>.from(e!.openPositions)
        : [];
    _perks = e?.perks != null ? List<String>.from(e!.perks) : [];
    if (e != null) {
      _category = e.category;
      _isOnline = e.isOnline;
      _isPaid = e.isPaid;
      _startDate = e.startTime;
      _startTime = TimeOfDay.fromDateTime(e.startTime);
      _endTime = TimeOfDay.fromDateTime(e.endTime);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _volunteersController.dispose();
    _minAgeController.dispose();
    _compensationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'GPS Location service is disabled. Please enable GPS.',
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied. Enter coordinates manually.',
              ),
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        if (_addressController.text.trim().isEmpty) {
          _addressController.text =
              'GPS Pin (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fetched GPS Coordinates: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
            ),
            backgroundColor: const Color(0xFF006C48),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _showLocationPickerModal(BuildContext context) {
    final presetVenues = [
      {
        'name': 'Central City Park',
        'lat': 12.9716,
        'lng': 77.5946,
        'addr': 'Central City Park, MG Road',
      },
      {
        'name': 'Community Service Center',
        'lat': 12.9352,
        'lng': 77.6245,
        'addr': '8th Block Community Hall, Koramangala',
      },
      {
        'name': 'Greenwood Nature Reserve',
        'lat': 13.0358,
        'lng': 77.5970,
        'addr': 'Greenwood Lake Gate 2, Hebbal',
      },
      {
        'name': 'Memorial Public Square',
        'lat': 12.9757,
        'lng': 77.6011,
        'addr': 'Cubbon Park Square, Kasturba Rd',
      },
      {
        'name': 'Youth Cultural Center',
        'lat': 12.9250,
        'lng': 77.5938,
        'addr': 'Jayanagar 4th Block Cultural Complex',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Event Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF012D1D),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _getCurrentLocation();
                },
                icon: const Icon(Icons.my_location, color: Color(0xFF006C48)),
                label: const Text(
                  'Use My Current GPS Position',
                  style: TextStyle(
                    color: Color(0xFF006C48),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF006C48)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Or Select Nearby Location Preset:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF717973),
                ),
              ),
              const SizedBox(height: 8),
              ...presetVenues.map(
                (v) => ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8EFF1),
                    child: Icon(Icons.location_on, color: Color(0xFF006C48)),
                  ),
                  title: Text(
                    v['name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${v['addr']} (${v['lat']}, ${v['lng']})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    setState(() {
                      _addressController.text = v['addr'] as String;
                      _latitudeController.text = (v['lat'] as double)
                          .toString();
                      _longitudeController.text = (v['lng'] as double)
                          .toString();
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Selected venue: ${v['name']}'),
                        backgroundColor: const Color(0xFF006C48),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectBannerUrl(BuildContext context) {
    final presets = {
      'Environmental':
          'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=600&auto=format&fit=crop&q=80',
      'Medical':
          'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=600&auto=format&fit=crop&q=80',
      'Education':
          'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=600&auto=format&fit=crop&q=80',
      'Animal Welfare':
          'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?w=600&auto=format&fit=crop&q=80',
      'Disaster Relief':
          'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=600&auto=format&fit=crop&q=80',
      'Social Awareness':
          'https://images.unsplash.com/photo-1509099836639-18ba1795216d?w=600&auto=format&fit=crop&q=80',
    };

    final urlController = TextEditingController(text: _bannerUrl ?? '');
    bool isUploading = false;
    String uploadStatus = '';

    Future<void> pickAndUploadImage(
      ImageSource source,
      StateSetter setModalState,
    ) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
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
          imageQuality: 85,
        );

        if (image == null) return;

        setModalState(() {
          isUploading = true;
          uploadStatus = 'Reading image file...';
        });

        final bytes = await image.readAsBytes();

        setModalState(() {
          uploadStatus = 'Uploading cover image...';
        });

        final auth = Provider.of<AuthService>(context, listen: false);
        final eventService = Provider.of<EventService>(context, listen: false);

        if (auth.token != null) {
          final uploadedUrl = await eventService.uploadEventImage(
            auth.token!,
            bytes,
            image.name,
          );

          if (uploadedUrl != null) {
            if (!mounted) return;
            setState(() {
              _bannerUrl = uploadedUrl;
            });
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo uploaded and added successfully!'),
                backgroundColor: Color(0xFF006C48),
              ),
            );
            return;
          }
        }
      } catch (e) {
        debugPrint('[UPLOAD ERROR] $e');
      }

      setModalState(() {
        isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to upload photo. Please check server connection.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DefaultTabController(
              length: 3,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose Event Banner Photo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF012D1D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const TabBar(
                      labelColor: Color(0xFF012D1D),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFF0E6C4A),
                      tabs: [
                        Tab(text: 'Upload Photo'),
                        Tab(text: 'Preset Library'),
                        Tab(text: 'Custom URL'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isUploading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF0E6C4A),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              uploadStatus,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFF012D1D),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 240,
                        child: TabBarView(
                          children: [
                            // Tab 1: Local Upload from Phone
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Upload cover image from your device:',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF717973),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => pickAndUploadImage(
                                            ImageSource.gallery,
                                            setModalState,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Container(
                                            height: 120,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: const Color(0xFFE8EFF1),
                                                width: 2,
                                              ),
                                              color: const Color(0xFFF4FAFD),
                                            ),
                                            child: const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.photo_library_outlined,
                                                  size: 36,
                                                  color: Color(0xFF0E6C4A),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Choose Gallery',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Color(0xFF012D1D),
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Select from photos',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => pickAndUploadImage(
                                            ImageSource.camera,
                                            setModalState,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Container(
                                            height: 120,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: const Color(0xFFE8EFF1),
                                                width: 2,
                                              ),
                                              color: const Color(0xFFF4FAFD),
                                            ),
                                            child: const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.camera_alt_outlined,
                                                  size: 36,
                                                  color: Color(0xFF0E6C4A),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Take Photo',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Color(0xFF012D1D),
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Snap with camera',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Tab 2: High quality curated presets
                            ListView(
                              children: presets.entries.map((entry) {
                                final isSelected = _bannerUrl == entry.value;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _bannerUrl = entry.value;
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    height: 70,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF0E6C4A)
                                            : const Color(0xFFE8EFF1),
                                        width: 2.5,
                                      ),
                                      image: DecorationImage(
                                        image: NetworkImage(entry.value),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    child: Container(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.black45,
                                      ),
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            // Tab 3: Custom URL input
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Provide a custom image URL:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF717973),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: urlController,
                                  decoration: InputDecoration(
                                    hintText: 'https://example.com/image.jpg',
                                    fillColor: const Color(0xFFF4FAFD),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () {
                                    final text = urlController.text.trim();
                                    setState(() {
                                      _bannerUrl = text.isNotEmpty
                                          ? text
                                          : null;
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF012D1D),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: const Text(
                                    'Save Custom URL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addPositionDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Add Open Position',
            style: TextStyle(
              color: Color(0xFF012D1D),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Eco Team Lead',
              fillColor: const Color(0xFFF4FAFD),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006C48),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty && !_openPositions.contains(text)) {
                  setState(() {
                    _openPositions.add(text);
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addPerkDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Add Perk or Benefit',
            style: TextStyle(
              color: Color(0xFF012D1D),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Free T-Shirt & Lunch',
              fillColor: const Color(0xFFF4FAFD),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006C48),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty && !_perks.contains(text)) {
                  setState(() {
                    _perks.add(text);
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final eventService = Provider.of<EventService>(context, listen: false);

    if (auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Not authenticated.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    final lat = !_isOnline
        ? double.tryParse(_latitudeController.text.trim())
        : null;
    final lon = !_isOnline
        ? double.tryParse(_longitudeController.text.trim())
        : null;

    final result = widget.eventToEdit != null
        ? await eventService.updateEvent(
            token: auth.token!,
            eventId: widget.eventToEdit!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            bannerUrl: _bannerUrl,
            address: _addressController.text.trim(),
            latitude: lat,
            longitude: lon,
            isOnline: _isOnline,
            startTime: startDateTime,
            endTime: endDateTime,
            volunteersNeeded: int.parse(_volunteersController.text),
            minAge: int.parse(_minAgeController.text),
            isPaid: _isPaid,
            compensationDetails: _isPaid
                ? _compensationController.text.trim()
                : null,
            openPositions: _openPositions,
            perks: _perks,
          )
        : await eventService.createEvent(
            token: auth.token!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            bannerUrl: _bannerUrl,
            address: _addressController.text.trim(),
            latitude: lat,
            longitude: lon,
            isOnline: _isOnline,
            startTime: startDateTime,
            endTime: endDateTime,
            volunteersNeeded: int.parse(_volunteersController.text),
            minAge: int.parse(_minAgeController.text),
            isPaid: _isPaid,
            compensationDetails: _isPaid
                ? _compensationController.text.trim()
                : null,
            openPositions: _openPositions,
            perks: _perks,
          );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.eventToEdit != null
                  ? 'Event updated successfully!'
                  : 'Event published successfully!',
            ),
          ),
        );
        // Refresh event list for dashboard
        eventService.fetchEvents();

        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(true);
        } else {
          // Reset form fields
          _titleController.clear();
          _descriptionController.clear();
          _addressController.clear();
          _latitudeController.clear();
          _longitudeController.clear();
          _volunteersController.text = '10';
          _minAgeController.text = '16';
          _compensationController.clear();
          setState(() {
            _bannerUrl = null;
            _category = 'Environmental';
            _isOnline = false;
            _isPaid = false;
            _startDate = DateTime.now().add(const Duration(days: 1));
            _startTime = const TimeOfDay(hour: 9, minute: 0);
            _endTime = const TimeOfDay(hour: 17, minute: 0);
            _openPositions = [];
            _perks = [];
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to save event.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          widget.eventToEdit != null ? 'Edit Event' : 'Create Event',
          style: GoogleFonts.plusJakartaSans(
            textStyle: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 760,
        child: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Banner Image Selection Box
                      GestureDetector(
                        onTap: () => _selectBannerUrl(context),
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EFF1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFC1C8C2)),
                            image: _bannerUrl != null && _bannerUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_bannerUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _bannerUrl != null && _bannerUrl!.isNotEmpty
                              ? Stack(
                                  children: [
                                    Positioned(
                                      right: 12,
                                      top: 12,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        radius: 16,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          onPressed: () =>
                                              _selectBannerUrl(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.image_outlined,
                                      color: Color(0xFF006C48),
                                      size: 36,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.eventToEdit != null
                                          ? 'Edit Event Banner'
                                          : 'Upload Event Banner',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Tap to choose preset or enter custom image URL',
                                      style: TextStyle(
                                        color: Color(0xFF717973),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title Field
                      Text(
                        'Event Title',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Title is required'
                            : null,
                        decoration: InputDecoration(
                          hintText: 'e.g. Greenwood Park Tree Planting',
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8EFF1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8EFF1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Category field
                      Text(
                        'Category',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8EFF1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _category,
                            isExpanded: true,
                            items:
                                <String>[
                                  'Environmental',
                                  'Medical',
                                  'Education',
                                  'Animal Welfare',
                                  'Disaster Relief',
                                  'Social Awareness',
                                ].map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(() {
                                  _category = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description Field
                      Text(
                        'Description',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Description is required'
                            : null,
                        decoration: InputDecoration(
                          hintText:
                              'Share details about the mission, requirements, and schedule...',
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8EFF1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8EFF1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Address / Location
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Address & Location',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Row(
                            children: [
                              const Text(
                                'Online Event',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF717973),
                                ),
                              ),
                              Switch(
                                value: _isOnline,
                                activeColor: const Color(0xFF006C48),
                                onChanged: (v) => setState(() => _isOnline = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _addressController,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Address is required'
                            : null,
                        decoration: InputDecoration(
                          hintText: 'e.g. Greenwood Nature Park, Gate 3',
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF717973),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.map,
                              color: Color(0xFF006C48),
                            ),
                            tooltip: 'Pick / Find Location on Map',
                            onPressed: () => _showLocationPickerModal(context),
                          ),
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8EFF1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8EFF1),
                            ),
                          ),
                        ),
                      ),
                      if (!_isOnline) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: _isGettingLocation
                                  ? null
                                  : _getCurrentLocation,
                              icon: _isGettingLocation
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.my_location,
                                      size: 16,
                                      color: Color(0xFF006C48),
                                    ),
                              label: Text(
                                _isGettingLocation
                                    ? 'Fetching GPS...'
                                    : 'Get Current GPS Location',
                                style: const TextStyle(
                                  color: Color(0xFF006C48),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _showLocationPickerModal(context),
                              icon: const Icon(
                                Icons.pin_drop,
                                size: 16,
                                color: Color(0xFF012D1D),
                              ),
                              label: const Text(
                                'Pick Venue',
                                style: TextStyle(
                                  color: Color(0xFF012D1D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Latitude',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _latitudeController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (v) =>
                                        !_isOnline &&
                                            (v == null ||
                                                v.trim().isEmpty ||
                                                double.tryParse(v) == null)
                                        ? 'Enter latitude'
                                        : null,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 12.9716',
                                      fillColor: Colors.white,
                                      filled: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE8EFF1),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE8EFF1),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Longitude',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _longitudeController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (v) =>
                                        !_isOnline &&
                                            (v == null ||
                                                v.trim().isEmpty ||
                                                double.tryParse(v) == null)
                                        ? 'Enter longitude'
                                        : null,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 77.5946',
                                      fillColor: Colors.white,
                                      filled: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE8EFF1),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE8EFF1),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Date & Time pickers
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => _selectDate(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE8EFF1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                        ),
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: Color(0xFF006C48),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Time',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => _selectTime(context, true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE8EFF1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_startTime.format(context)),
                                        const Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Color(0xFF006C48),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Time',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => _selectTime(context, false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE8EFF1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_endTime.format(context)),
                                        const Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Color(0xFF006C48),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Volunteers settings
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Volunteers Needed',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _volunteersController,
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      v == null || int.tryParse(v) == null
                                      ? 'Enter number'
                                      : null,
                                  decoration: InputDecoration(
                                    fillColor: Colors.white,
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE8EFF1),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE8EFF1),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Min Age',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _minAgeController,
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      v == null || int.tryParse(v) == null
                                      ? 'Enter number'
                                      : null,
                                  decoration: InputDecoration(
                                    fillColor: Colors.white,
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE8EFF1),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE8EFF1),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Sponsor / Paid switch
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sponsored Event',
                                style: TextStyle(
                                  color: Color(0xFF012D1D),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Compensate volunteers with perks/stipends',
                                style: TextStyle(
                                  color: Color(0xFF717973),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isPaid,
                            activeColor: const Color(0xFF006C48),
                            onChanged: (v) => setState(() => _isPaid = v),
                          ),
                        ],
                      ),
                      if (_isPaid) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _compensationController,
                          validator: (v) =>
                              _isPaid && (v == null || v.trim().isEmpty)
                              ? 'Compensation details required'
                              : null,
                          decoration: InputDecoration(
                            hintText:
                                'e.g. Free lunch & T-shirt, 20 USD travel stipend',
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE8EFF1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE8EFF1),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'Open Positions',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8EFF1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_openPositions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No custom positions added yet. Default campaign roles will be used.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _openPositions.map((pos) {
                                  return Chip(
                                    label: Text(
                                      pos,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF012D1D),
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFCEE9D3),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Color(0xFF012D1D),
                                    ),
                                    onDeleted: () {
                                      setState(() {
                                        _openPositions.remove(pos);
                                      });
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    side: BorderSide.none,
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _addPositionDialog(context),
                              icon: const Icon(
                                Icons.add,
                                size: 16,
                                color: Color(0xFF006C48),
                              ),
                              label: const Text(
                                'Add Custom Position',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF006C48),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF006C48),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'Perks & Benefits',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8EFF1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_perks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No custom perks added yet. Default perks will be shown.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _perks.map((perk) {
                                  return Chip(
                                    label: Text(
                                      perk,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF0E6C4A),
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFE8EFF1),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Color(0xFF0E6C4A),
                                    ),
                                    onDeleted: () {
                                      setState(() {
                                        _perks.remove(perk);
                                      });
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    side: BorderSide.none,
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _addPerkDialog(context),
                              icon: const Icon(
                                Icons.add,
                                size: 16,
                                color: Color(0xFF006C48),
                              ),
                              label: const Text(
                                'Add Custom Perk',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF006C48),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF006C48),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _submit,
                        child: Text(
                          widget.eventToEdit != null
                              ? 'Save Changes'
                              : 'Publish Event',
                          style: GoogleFonts.plusJakartaSans(
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
