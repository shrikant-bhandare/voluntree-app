import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/event_service.dart';
import '../services/category_service.dart';
import '../services/auth_service.dart';
import 'event_detail_screen.dart';
import '../utils/drive_cta.dart';
import '../utils/spots_remaining.dart';
import '../utils/list_state.dart';
import '../utils/event_time.dart';

class DiscoverEventsScreen extends StatefulWidget {
  final bool isEmbedded;
  const DiscoverEventsScreen({super.key, this.isEmbedded = false});

  @override
  State<DiscoverEventsScreen> createState() => _DiscoverEventsScreenState();
}

class _DiscoverEventsScreenState extends State<DiscoverEventsScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  bool _nearbyEnabled = false;
  double _radius = 10.0; // km
  Timer? _searchDebounce;

  bool _showRecommendations = false;
  List<EventModel> _recommendations = [];
  bool _loadingRecommendations = false;

  // Device position, resolved when the distance filter is switched on.
  double? _userLat;
  double? _userLon;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    // Load events on screen start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      Provider.of<CategoryService>(context, listen: false).ensureLoaded();
    });
  }

  void _loadRecommendations() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final eventService = Provider.of<EventService>(context, listen: false);

    if (authService.token == null) return;

    setState(() {
      _loadingRecommendations = true;
    });

    final list = await eventService.fetchRecommendations(authService.token!);

    if (mounted) {
      setState(() {
        _recommendations = list;
        _loadingRecommendations = false;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    final eventService = Provider.of<EventService>(context, listen: false);
    final useGeo = _nearbyEnabled && _userLat != null && _userLon != null;
    eventService.fetchEvents(
      category: _selectedCategory,
      search: _searchController.text.trim(),
      latitude: useGeo ? _userLat : null,
      longitude: useGeo ? _userLon : null,
      radius: useGeo ? _radius : null,
    );
  }

  /// Search fired per keystroke; wait for a pause so three letters do not
  /// become three requests racing to overwrite each other.
  void _scheduleRefresh() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _refresh);
  }

  /// The old filter used hard-coded Bengaluru coordinates for everyone.
  Future<void> _setNearby(bool enabled) async {
    if (!enabled) {
      setState(() => _nearbyEnabled = false);
      _refresh();
      return;
    }
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLon = pos.longitude;
        _nearbyEnabled = true;
      });
      _refresh();
    } catch (e) {
      debugPrint('[DISCOVER] location unavailable: $e');
      if (!mounted) return;
      setState(() => _nearbyEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not get your location. Check location permissions and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// The signed-in volunteer's applications, refreshed each build.
  List<dynamic> _applications = const [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventService = Provider.of<EventService>(context);
    final events = eventService.events;
    final isLoading = eventService.isLoading;
    // Captured here rather than watched inside the card: cards are produced
    // from an itemBuilder, which runs during layout, and registering a
    // dependency there makes a later notifyListeners dirty the element
    // mid-layout ("setState() called during build").
    _applications = eventService.userApplications;
    final feedState = listStateFor(
      hasLoaded: eventService.hasLoadedEvents,
      count: events.length,
      failed: eventService.eventsLoadFailed,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: theme.colorScheme.primary,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'Discover Events',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search & Filter Panel
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8EFF1), width: 1.5),
              ),
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  onChanged: (_) => _scheduleRefresh(),
                  decoration: InputDecoration(
                    hintText: 'Search event titles or keywords...',
                    hintStyle: const TextStyle(color: Color(0xFF717973)),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.secondary,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF4FAFD),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFFE8EFF1),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category chips (Horizontal scroll), from the server's list.
                Builder(
                  builder: (context) {
                    final categories = [
                      'All',
                      ...Provider.of<CategoryService>(context).categories,
                    ];
                    return SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: theme.colorScheme.primary,
                              backgroundColor: const Color(0xFFF4FAFD),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF717973),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : const Color(0xFFE8EFF1),
                                  width: 1,
                                ),
                              ),
                              showCheckmark: false,
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    _selectedCategory = cat;
                                  });
                                  _refresh();
                                }
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // GPS nearby filter toggles
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8EFF1), width: 1.5),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: theme.colorScheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Filter by distance (GPS)',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _nearbyEnabled,
                      activeColor: theme.colorScheme.secondary,
                      onChanged: _locating ? null : (val) => _setNearby(val),
                    ),
                  ],
                ),
                if (_nearbyEnabled) ...[
                  Row(
                    children: [
                      Text(
                        'Radius: ${_radius.round()} km',
                        style: const TextStyle(
                          color: Color(0xFF717973),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _radius,
                          min: 2,
                          max: 50,
                          // Whole kilometres: the API rejects a fractional
                          // radius, and a free slider produced 27.34…
                          divisions: 48,
                          activeColor: theme.colorScheme.secondary,
                          inactiveColor: const Color(0xFFE8EFF1),
                          onChanged: (val) {
                            setState(() {
                              _radius = val;
                            });
                          },
                          onChangeEnd: (_) => _refresh(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Toggle selector row between Explore & AI
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8EFF1), width: 1.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showRecommendations = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !_showRecommendations
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Explore Feed',
                        style: TextStyle(
                          color: !_showRecommendations
                              ? theme.colorScheme.primary
                              : const Color(0xFF717973),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showRecommendations = true;
                      });
                      _loadRecommendations();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _showRecommendations
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'AI Recommendations ⚡',
                        style: TextStyle(
                          color: _showRecommendations
                              ? theme.colorScheme.primary
                              : const Color(0xFF717973),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Events Feed list
          Expanded(
            child: _showRecommendations
                ? _loadingRecommendations
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.secondary,
                            ),
                          ),
                        )
                      : _recommendations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.psychology_outlined,
                                size: 64,
                                color: Color(0xFF717973),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No AI recommendations yet',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Text(
                                  'Define interests on your Profile screen to match custom campaigns.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF717973),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _loadRecommendations(),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _recommendations.length,
                            itemBuilder: (context, index) {
                              final event = _recommendations[index];
                              return _buildEventCard(event);
                            },
                          ),
                        )
                : isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.secondary,
                      ),
                    ),
                  )
                : feedState == ListState.failed
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 64,
                          color: Color(0xFF717973),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load drives',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF717973),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.event_busy_outlined,
                          size: 64,
                          color: Color(0xFF717973),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matching events found',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try modifying your filters or search keywords.',
                          style: TextStyle(
                            color: Color(0xFF717973),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return _buildEventCard(event);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(EventModel event) {
    final theme = Theme.of(context);
    final dateStr = formatLocalDate(event.startTime);
    final timeStr = formatLocalTime(event.startTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EFF1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primaryContainer.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EventDetailScreen(event: event),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Banner Header
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              event.category.toUpperCase(),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (event.matchScore != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E6C4A),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${event.matchScore}% MATCH ⚡',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Details Body
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: Color(0xFF717973),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$dateStr at $timeStr',
                          style: const TextStyle(
                            color: Color(0xFF717973),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (event.isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9A24A).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SPONSORED',
                              style: TextStyle(
                                color: Color(0xFFC9A24A),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Color(0xFF717973),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF717973),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (event.distance != null)
                          Text(
                            '${event.distance!.toStringAsFixed(1)} km away',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const Divider(color: Color(0xFFE8EFF1), height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Same wording and the same application-aware CTA the
                        // home carousel uses. The two listings previously
                        // disagreed about one drive: "24 spots left / Pending"
                        // on the home screen, "25 Volunteers Needed / Join
                        // drive" here.
                        Text(
                          spotsLabel(
                            volunteersNeeded: event.volunteersNeeded,
                            approvedCount: event.approvedCount,
                          ),
                          style: TextStyle(
                            color:
                                spotsAreScarce(
                                  volunteersNeeded: event.volunteersNeeded,
                                  approvedCount: event.approvedCount,
                                )
                                ? const Color(0xFFBA1A1A)
                                : theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Builder(
                          builder: (_) {
                            final cta = driveCtaFor(
                              eventId: event.id,
                              userApplications: _applications,
                            );
                            return Text(
                              cta.isApplied ? cta.label : 'Join drive',
                              style: TextStyle(
                                color: cta.isApplied
                                    ? Colors.grey[600]
                                    : theme.colorScheme.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
