import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/event_service.dart';

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

  String _category = 'Environmental';
  bool _isOnline = false;
  bool _isPaid = false;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  String? _bannerUrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.eventToEdit;
    _bannerUrl = e?.bannerUrl;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');
    _volunteersController = TextEditingController(text: e != null ? e.volunteersNeeded.toString() : '10');
    _minAgeController = TextEditingController(text: e != null ? e.minAge.toString() : '16');
    _compensationController = TextEditingController(text: e?.compensationDetails ?? '');
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

  void _selectBannerUrl(BuildContext context) {
    final presets = {
      'Environmental': 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=600&auto=format&fit=crop&q=80',
      'Medical': 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=600&auto=format&fit=crop&q=80',
      'Education': 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=600&auto=format&fit=crop&q=80',
      'Animal Welfare': 'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?w=600&auto=format&fit=crop&q=80',
      'Disaster Relief': 'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=600&auto=format&fit=crop&q=80',
      'Social Awareness': 'https://images.unsplash.com/photo-1509099836639-18ba1795216d?w=600&auto=format&fit=crop&q=80',
    };

    final galleryPhotos = [
      'https://images.unsplash.com/photo-1448375240586-882707db888b?w=600',
      'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?w=600',
      'https://images.unsplash.com/photo-1427504494785-3a9ca7044f45?w=600',
      'https://images.unsplash.com/photo-1596492784531-6e6eb5ea9993?w=600',
      'https://images.unsplash.com/photo-1547082299-de196ea013d6?w=600',
      'https://images.unsplash.com/photo-1461530967064-3000627ae6c3?w=600',
    ];

    final urlController = TextEditingController(text: _bannerUrl ?? '');
    bool isUploading = false;
    String uploadStatus = '';

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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF012D1D)),
                    ),
                    const SizedBox(height: 12),
                    const TabBar(
                      labelColor: Color(0xFF012D1D),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFF0E6C4A),
                      tabs: [
                        Tab(text: 'Local Gallery'),
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
                            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0E6C4A))),
                            const SizedBox(height: 16),
                            Text(
                              uploadStatus,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF012D1D)),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 240,
                        child: TabBarView(
                          children: [
                            // Tab 1: Simulated local device gallery
                            GridView.builder(
                              shrinkWrap: true,
                              itemCount: galleryPhotos.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemBuilder: (context, index) {
                                final photoUrl = galleryPhotos[index];
                                return GestureDetector(
                                  onTap: () async {
                                    setModalState(() {
                                      isUploading = true;
                                      uploadStatus = 'Downloading image bytes...';
                                    });

                                    try {
                                      // 1. Download the high quality preset image to simulate local file bytes
                                      final response = await http.get(Uri.parse(photoUrl));
                                      if (response.statusCode == 200) {
                                        setModalState(() {
                                          uploadStatus = 'Uploading photo to server...';
                                        });

                                        final auth = Provider.of<AuthService>(context, listen: false);
                                        final eventService = Provider.of<EventService>(context, listen: false);

                                        if (auth.token != null) {
                                          // 2. Upload file bytes via multipart form data request
                                          final uploadedUrl = await eventService.uploadEventImage(
                                            auth.token!,
                                            response.bodyBytes,
                                            'device_gallery_upload_$index.jpg',
                                          );

                                          if (uploadedUrl != null) {
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
                                      }
                                    } catch (e) {
                                      debugPrint('[UPLOAD ERROR] $e');
                                    }

                                    setModalState(() {
                                      isUploading = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to upload photo. Please check server connection.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(photoUrl, fit: BoxFit.cover),
                                        Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                            child: const Icon(Icons.add, color: Colors.white, size: 14),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
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
                                        color: isSelected ? const Color(0xFF0E6C4A) : const Color(0xFFE8EFF1),
                                        width: 2.5,
                                      ),
                                      image: DecorationImage(
                                        image: NetworkImage(entry.value),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    child: Container(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.black45,
                                      ),
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
                                  style: TextStyle(fontSize: 12, color: Color(0xFF717973), fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: urlController,
                                  decoration: InputDecoration(
                                    hintText: 'https://example.com/image.jpg',
                                    fillColor: const Color(0xFFF4FAFD),
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () {
                                    final text = urlController.text.trim();
                                    setState(() {
                                      _bannerUrl = text.isNotEmpty ? text : null;
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF012D1D),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('Save Custom URL', style: TextStyle(fontWeight: FontWeight.bold)),
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

    final result = widget.eventToEdit != null
        ? await eventService.updateEvent(
            token: auth.token!,
            eventId: widget.eventToEdit!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            bannerUrl: _bannerUrl,
            address: _addressController.text.trim(),
            isOnline: _isOnline,
            startTime: startDateTime,
            endTime: endDateTime,
            volunteersNeeded: int.parse(_volunteersController.text),
            minAge: int.parse(_minAgeController.text),
            isPaid: _isPaid,
            compensationDetails: _isPaid ? _compensationController.text.trim() : null,
          )
        : await eventService.createEvent(
            token: auth.token!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            bannerUrl: _bannerUrl,
            address: _addressController.text.trim(),
            isOnline: _isOnline,
            startTime: startDateTime,
            endTime: endDateTime,
            volunteersNeeded: int.parse(_volunteersController.text),
            minAge: int.parse(_minAgeController.text),
            isPaid: _isPaid,
            compensationDetails: _isPaid ? _compensationController.text.trim() : null,
          );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.eventToEdit != null ? 'Event updated successfully!' : 'Event published successfully!')),
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
      body: _isSaving
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
                                        icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                                        onPressed: () => _selectBannerUrl(context),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.image_outlined, color: Color(0xFF006C48), size: 36),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.eventToEdit != null ? 'Edit Event Banner' : 'Upload Event Banner',
                                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const Text(
                                    'Tap to choose preset or enter custom image URL',
                                    style: TextStyle(color: Color(0xFF717973), fontSize: 11),
                                  )
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title Field
                    Text('Event Title', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                      decoration: InputDecoration(
                        hintText: 'e.g. Greenwood Park Tree Planting',
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category field
                    Text('Category', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
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
                          items: <String>[
                            'Environmental',
                            'Medical',
                            'Education',
                            'Animal Welfare',
                            'Disaster Relief',
                            'Social Awareness'
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
                    Text('Description', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
                      decoration: InputDecoration(
                        hintText: 'Share details about the mission, requirements, and schedule...',
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Address / Location
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Address & Location', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                        Row(
                          children: [
                            const Text('Online Event', style: TextStyle(fontSize: 12, color: Color(0xFF717973))),
                            Switch(
                              value: _isOnline,
                              activeColor: const Color(0xFF006C48),
                              onChanged: (v) => setState(() => _isOnline = v),
                            ),
                          ],
                        )
                      ],
                    ),
                    TextFormField(
                      controller: _addressController,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
                      decoration: InputDecoration(
                        hintText: 'e.g. Greenwood Nature Park, Gate 3',
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF717973)),
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date & Time pickers
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _selectDate(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE8EFF1)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF006C48)),
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
                              Text('Start Time', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _selectTime(context, true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE8EFF1)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_startTime.format(context)),
                                      const Icon(Icons.access_time, size: 16, color: Color(0xFF006C48)),
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
                              Text('Volunteers Needed', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _volunteersController,
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || int.tryParse(v) == null ? 'Enter number' : null,
                                decoration: InputDecoration(
                                  fillColor: Colors.white,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
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
                              Text('Min Age', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _minAgeController,
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || int.tryParse(v) == null ? 'Enter number' : null,
                                decoration: InputDecoration(
                                  fillColor: Colors.white,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
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
                            Text('Sponsored Event', style: TextStyle(color: Color(0xFF012D1D), fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Compensate volunteers with perks/stipends', style: TextStyle(color: Color(0xFF717973), fontSize: 11)),
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
                        validator: (v) => _isPaid && (v == null || v.trim().isEmpty) ? 'Compensation details required' : null,
                        decoration: InputDecoration(
                          hintText: 'e.g. Free lunch & T-shirt, 20 USD travel stipend',
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EFF1))),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      onPressed: _submit,
                      child: Text(
                        widget.eventToEdit != null ? 'Save Changes' : 'Publish Event',
                        style: GoogleFonts.plusJakartaSans(
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
